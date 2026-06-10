class ForecastRunnerJob < ApplicationJob
  queue_as :default

  def perform(horizon_days: 7)
    run = ForecastRun.create!(run_at: Time.current, horizon_days: horizon_days, model: 'regression')
    horizon_days = horizon_days.to_i
    window_start = Time.current.beginning_of_day
    window_end = (window_start + (horizon_days - 1).days).end_of_day
    
    # Видаляємо старі прогнози для цього периоду
    Forecast.where('showtime_at >= ? AND showtime_at <= ?', window_start, window_end).delete_all
    
    # Cache for movie occupancies to avoid N+1 queries
    movie_occupancy_cache = {}
    # Cache for movie release dates to avoid N+1 queries
    release_dates_cache = {}

    Hall.find_each do |hall|
      capacity = hall.capacity.to_i
      next if capacity <= 0

      Rails.logger.info("FORECAST DEBUG: Processing Hall #{hall.id} with capacity #{capacity}")
      
      rows = gather_training_rows_for(hall, capacity, movie_occupancy_cache, release_dates_cache)
      Rails.logger.info("FORECAST DEBUG: Hall #{hall.id} gathered #{rows.count} training rows")
      next if rows.empty?

      trainer = Forecasting::RegressionTrainer.new(rows)
      model = trainer.train(ridge: 0.01)
      
      Rails.logger.info("FORECAST DEBUG Hall #{hall.id}: Model nil? #{model.nil?}")
      
      if model.nil?
        Rails.logger.info("FORECAST DEBUG Hall #{hall.id}: Model is nil! Skipping.")
        next
      end
      
      Rails.logger.info("FORECAST DEBUG Hall #{hall.id}: Coefs=#{model[:coefs].inspect}")
      Rails.logger.info("FORECAST DEBUG Hall #{hall.id}: Features=#{model[:feature_names].inspect}")
      
      upcoming_showtimes = hall.showtimes.where('start_time >= ? AND start_time <= ?', window_start, window_end)

      upcoming_showtimes.each do |showtime|
        hour = showtime.start_time.hour
        is_wknd = showtime.start_time.saturday? || showtime.start_time.sunday?

        # Визначаємо дефолтну популярність з урахуванням часу доби та дня тижня
        movie_pop = cached_historical_occupancy(showtime.movie_id, movie_occupancy_cache) ||
          default_occupancy_for_movie(
            showtime.movie,
            showtime.start_time.to_date,
            release_dates_cache,
            hour: hour,
            is_weekend: is_wknd
          )

        is_morning = (hour >= 8 && hour < 12)
        is_afternoon = (hour >= 12 && hour < 17)
        is_evening = (hour >= 17)
        slot_floor = minimum_floor_for_slot_with_day_factor(hour, is_wknd)

        features = {
          movie_popularity: movie_pop,
          lag_feature: lag_feature_for_showtime(showtime),
          start_time: showtime.start_time,
          movie_id: showtime.movie_id,
          hall_id: showtime.hall_id,
          release_date: get_movie_release_date(showtime.movie_id, release_dates_cache),
          is_weekend: is_wknd,
          is_morning: is_morning,
          is_afternoon: is_afternoon,
          is_evening: is_evening
        }

        baseline_occupancy = [movie_pop, slot_floor].max
        raw_occupancy = trainer.predict(model, features)

        # Згладжуємо регресію базовою історичною популярністю, щоб уникати різких провалів.
        occupancy = raw_occupancy.nil? ? baseline_occupancy : ((raw_occupancy * 0.55) + (baseline_occupancy * 0.45))
        occupancy = slot_floor if occupancy < slot_floor
        occupancy = 0.95 if occupancy > 0.95

        # Apply new release multiplier based on showtime date, not current date
        days_since_release = calculate_days_since_release(showtime.movie, showtime.start_time.to_date, release_dates_cache)
        new_release_multiplier = case days_since_release
          when 0..3  then 1.30   # +30%
          when 4..7  then 1.10   # +10%
          when 8..11 then 0.90   # -10%
          when 12..13 then 0.85  # -15%
          when 14..20 then 0.65  # -35%
          else 0.50              # -50% after 21 days
        end

        # Послаблюємо прем'єрний буст для денних сеансів у будні:
        # вдень навіть на прем'єру ажіотаж значно менший
        if !is_wknd && hour < 18
          new_release_multiplier = 1.0 + (new_release_multiplier - 1.0) * 0.5
        end

        occupancy = occupancy * new_release_multiplier
        occupancy = 0.95 if occupancy > 0.95

        predicted_tickets = (occupancy * capacity).round
        
        # Debug: log prediction details for evening showtimes
        if is_evening
          Rails.logger.info("FORECAST DEBUG Hall #{hall.id} Showtime #{showtime.id}: hour=#{hour}, evening=#{is_evening}, occupancy=#{occupancy.round(3)}, tickets=#{predicted_tickets}")
        end

        Forecast.create!(
          forecast_run: run,
          hall: hall,
          showtime: showtime,
          movie: showtime.movie,
          showtime_at: showtime.start_time,
          predicted_tickets: predicted_tickets,
          predicted_fill_pct: (occupancy * 100).round(2)
        )
      end
    end
  end

  private

  def gather_training_rows_for(hall, capacity, movie_cache = {}, release_dates_cache = {})
    rows = []
    # Exclude showtimes from the last 24 hours to avoid incomplete data
    past_showtimes = hall.showtimes.where('start_time < ?', Time.current - 24.hours).includes(:movie).to_a
    
    # Fetch all ticket counts in a single query to avoid N+1
    showtime_ids = past_showtimes.map(&:id)
    return [] if showtime_ids.empty?
    
    ticket_counts = Ticket.where(showtime_id: showtime_ids, status: %w[sold pending]).group(:showtime_id).count

    past_showtimes.each do |showtime|
      sold_tickets = ticket_counts[showtime.id].to_i
      occupancy = (sold_tickets.to_f / capacity)

      hour = showtime.start_time.hour
      is_wknd = showtime.start_time.saturday? || showtime.start_time.sunday?

      # Визначаємо дефолтну популярність з урахуванням часу доби та дня тижня
      movie_pop = cached_historical_occupancy(showtime.movie_id, movie_cache) ||
        default_occupancy_for_movie(
          showtime.movie,
          showtime.start_time.to_date,
          release_dates_cache,
          hour: hour,
          is_weekend: is_wknd
        )

      is_morning = (hour >= 8 && hour < 12)
      is_afternoon = (hour >= 12 && hour < 17)
      is_evening = (hour >= 17)
      
      # Use showtime date for accurate days_since_release calculation
      days_since = calculate_days_since_release(showtime.movie, showtime.start_time.to_date, release_dates_cache)
      
      rows << {
        occupancy_pct: occupancy,
        movie_popularity: movie_pop,
        lag_feature: lag_feature_for_showtime(showtime),
        start_time: showtime.start_time,
        movie_id: showtime.movie_id,
        hall_id: showtime.hall_id,
        release_date: get_movie_release_date(showtime.movie_id, release_dates_cache),
        is_weekend: is_wknd,
        is_morning: is_morning,
        is_afternoon: is_afternoon,
        is_evening: is_evening,
        days_since_release: days_since
      }
    end
    rows
  end

  def calculate_historical_occupancy(movie_id)
    # Exclude showtimes from the last 24 hours to avoid incomplete data
    past_showtimes = Showtime.where(movie_id: movie_id).where('start_time < ?', Time.current - 24.hours).includes(:hall)

    return nil if past_showtimes.empty?

    # Fetch all ticket counts in a single query to avoid N+1
    showtime_ids = past_showtimes.map(&:id)
    return nil if showtime_ids.empty?
    
    ticket_counts = Ticket.where(showtime_id: showtime_ids, status: %w[sold pending]).group(:showtime_id).count

    # Calculate occupancy for each showtime
    occupancies = past_showtimes.map do |s| 
      hall_capacity = s.hall.capacity.to_i
      next nil if hall_capacity <= 0
      
      sold_tickets = ticket_counts[s.id].to_i
      sold_tickets.to_f / hall_capacity
    end.compact
    
    return nil if occupancies.empty?

    # Use median instead of average to avoid outliers
    sorted = occupancies.sort
    median = if sorted.length.odd?
      sorted[sorted.length / 2]
    else
      (sorted[sorted.length / 2 - 1] + sorted[sorted.length / 2]) / 2.0
    end
    
    Rails.logger.info("FORECAST DEBUG: Фільм ID #{movie_id} | Медіана популярності: #{median.round(3)} (#{occupancies.length} сеансів)")
    
    median
  end

  def cached_historical_occupancy(movie_id, cache)
    cache[movie_id] ||= calculate_historical_occupancy(movie_id)
  end

  def get_movie_release_date(movie_id, cache)
    cache[movie_id] ||= begin
      first_showtime = Showtime.where(movie_id: movie_id).order(start_time: :asc).first
      first_showtime&.start_time&.to_date
    end
  end

  def lag_feature_for_showtime(showtime)
    return 0.0 if showtime.nil?

    target_time = showtime.start_time - 7.days
    historical_showtime = Showtime.where(movie_id: showtime.movie_id, hall_id: showtime.hall_id)
                                  .where('start_time <= ?', target_time)
                                  .order(start_time: :desc)
                                  .first

    return 0.0 if historical_showtime.nil?

    hall_capacity = historical_showtime.hall.capacity.to_i
    return 0.0 if hall_capacity <= 0

    sold_tickets = historical_showtime.tickets.where(status: %w[sold pending]).count
    sold_tickets.to_f / hall_capacity
  end

  def minimum_floor_for_slot_with_day_factor(hour, is_weekend)
    # На вихідні: нормальна заповненість весь день
    if is_weekend
      return 0.10 if hour >= 8 && hour < 12
      return 0.12 if hour >= 12 && hour < 17
      return 0.15
    end
    
    # На буденні:
    # - До 18:00 люди на роботі, мало відвідувачів
    # - Після 18:00 нормальна заповненість
    if hour < 18
      return 0.005 if hour >= 8 && hour < 12
      return 0.005 if hour >= 12 && hour < 15
      return 0.005 if hour >= 15 && hour < 18
      return 0.005  # ніч та рано з ранку
    end

    # Вечір на буденні: нормальна заповненість
    0.15
  end

  def calculate_days_since_release(movie, target_date, release_dates_cache)
    return 999 if movie.nil? || target_date.nil?

    release_date = get_movie_release_date(movie.id, release_dates_cache)
    return 999 if release_date.nil?

    # Calculate days relative to the target showtime date, not current date
    [(target_date - release_date).to_i, 0].max
  end

  # Повертає дефолтну заповненість для фільму без історії.
  # Враховує: день тижня + час доби — у будні вдень навіть прем'єра не збирає повний зал.
  def default_occupancy_for_movie(movie, target_date, release_dates_cache, hour: nil, is_weekend: nil)
    return 0.40 if movie.nil? || target_date.nil?

    release_date = get_movie_release_date(movie.id, release_dates_cache)
    return 0.40 if release_date.nil?

    days_since_release = (target_date - release_date).to_i

    if days_since_release >= 0 && days_since_release <= 3
      # Будній день до 18:00: прем'єра, але вдень ажіотаж значно менший
      if !is_weekend && hour && hour < 18
        return 0.20
      end
      # Вечір або вихідний: стандартне очікування для нового фільму
      return 0.40
    end

    # Старі фільми без історії — консервативне значення
    0.25
  end
end