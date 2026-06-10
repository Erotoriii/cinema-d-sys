class ForecastRunnerJob < ApplicationJob
  queue_as :default

  # Сегменти для окремих моделей
  SEGMENTS = %i[weekday_day weekday_night weekend].freeze

  def perform(horizon_days: 7)
    run = ForecastRun.create!(
        run_at: Time.current,
        horizon_days: horizon_days,
        model: 'segmented_regression'
        )
    horizon_days = horizon_days.to_i
    window_start = Time.current.beginning_of_day
    window_end = (window_start + (horizon_days - 1).days).end_of_day

    Forecast.where('showtime_at >= ? AND showtime_at <= ?', window_start, window_end).delete_all
    movie_occupancy_cache = {}
    release_dates_cache = {}

    Hall.find_each do |hall|
      capacity = hall.capacity.to_i
      next if capacity <= 0

      Rails.logger.info("FORECAST DEBUG: Processing Hall #{hall.id} with capacity #{capacity}")

      all_rows = gather_training_rows_for(hall, capacity, movie_occupancy_cache, release_dates_cache)
      Rails.logger.info("FORECAST DEBUG: Hall #{hall.id} gathered #{all_rows.count} total training rows")
      next if all_rows.empty?

      # Розбиваємо тренувальні дані на 3 сегменти
      segmented_rows = split_into_segments(all_rows)

      # Навчаємо окрему модель для кожного сегменту
      models = train_segmented_models(hall.id, segmented_rows)

      # Fallback: якщо якийсь сегмент не має достатньо даних — навчаємо глобальну модель
      global_trainer = Forecasting::RegressionTrainer.new(all_rows)
      global_model   = global_trainer.train(ridge: 0.01)
      Rails.logger.info("FORECAST DEBUG Hall #{hall.id}: Global fallback model nil? #{global_model.nil?}")

      upcoming_showtimes = hall.showtimes.where('start_time >= ? AND start_time <= ?', window_start, window_end)
      upcoming_showtimes.each do |showtime|
        hour    = showtime.start_time.hour
        is_wknd = showtime.start_time.saturday? || showtime.start_time.sunday?
        date    = showtime.start_time.to_date

        segment = classify_segment(hour, is_wknd)
        active_trainer = models[segment][:trainer]
        active_model   = models[segment][:model]

        if active_model.nil?
          active_trainer = global_trainer
          active_model   = global_model
        end
        next if active_model.nil?

        # Визначаємо популярність фільму
        movie_pop = cached_historical_occupancy(showtime.movie_id, movie_occupancy_cache) ||
          default_occupancy_for_movie(
            showtime.movie,
            date,
            release_dates_cache,
            hour: hour,
            is_weekend: is_wknd
          )

        is_morning   = (hour >= 8 && hour < 12)
        is_afternoon = (hour >= 12 && hour < 17)
        is_evening   = (hour >= 17)
        slot_floor   = minimum_floor_for_slot_with_day_factor(hour, is_wknd)

        features = {
          movie_popularity: movie_pop,
          lag_feature:      lag_feature_for_showtime(showtime, days_ago: 7),
          lag_2_weeks:      lag_feature_for_showtime(showtime, days_ago: 14),
          rolling_avg_7d:   rolling_avg_7d(hall, showtime, capacity),
          start_time:       showtime.start_time,
          movie_id:         showtime.movie_id,
          hall_id:          showtime.hall_id,
          release_date:     get_movie_release_date(showtime.movie_id, release_dates_cache),
          is_weekend:       is_wknd,
          is_morning:       is_morning,
          is_afternoon:     is_afternoon,
          is_evening:       is_evening,
          day_of_week:      day_of_week(date),
          week_of_month:    week_of_month(date),
          is_holiday:       is_holiday?(date)
        }

        baseline_occupancy = [movie_pop, slot_floor].max
        raw_occupancy      = active_trainer.predict(active_model, features)

        # Згладжуємо регресію базовою популярністю
        occupancy = raw_occupancy.nil? ? baseline_occupancy : ((raw_occupancy * 0.55) + (baseline_occupancy * 0.45))
        occupancy = slot_floor if occupancy < slot_floor
        occupancy = 0.95 if occupancy > 0.95

        # Мультиплікатор нового релізу (відносно дати сеансу)
        days_since_release    = calculate_days_since_release(showtime.movie, date, release_dates_cache)
        new_release_multiplier = release_multiplier_for(days_since_release)

        if segment == :weekday_day
          new_release_multiplier = 1.0 + (new_release_multiplier - 1.0) * 0.5
        end

        occupancy = (occupancy * new_release_multiplier).clamp(slot_floor, 0.95)
        predicted_tickets = (occupancy * capacity).round

        # Conservative fallback for weekday_day: very low predictions get floored
        # Data shows weekday daytime avg=74.95 tickets (range 4-132), high variance
        # If model predicts < 5 tickets for daytime, use conservative 10% capacity instead
        if segment == :weekday_day && predicted_tickets < 5
          conservative_tickets = (0.10 * capacity).round
          predicted_tickets = conservative_tickets
        end

        Forecast.create!(
          forecast_run:       run,
          hall:               hall,
          showtime:           showtime,
          movie:              showtime.movie,
          showtime_at:        showtime.start_time,
          predicted_tickets:  predicted_tickets,
          predicted_fill_pct: (occupancy * 100).round(2)
        )
      end
    end
  end

  private

  # ---------------------------------------------------------------------------
  # New Features for Phase 3
  # ---------------------------------------------------------------------------

  def is_holiday?(date)
    return false if date.nil?
    month_day = "#{date.month}-#{date.day}"
    fixed_holidays = %w[
      1-1    # New Year
      1-7    # Orthodox Christmas
      3-8    # Women's Day
      5-1    # Labour Day
      5-9    # Victory Day
      8-15   # Assumption of Mary
      10-14  # Kozak Day
      10-28  # Cossack Day
      11-1   # All Saints' Day
      12-25  # Christmas
    ]

    return true if fixed_holidays.include?(month_day)

    # Easter (complex calculation, hardcode a few years)
    # Easter dates for 2024-2028 (Orthodox calendar in Ukraine)
    easter_dates = [
      Date.new(2024, 5, 5),   # Easter 2024
      Date.new(2025, 4, 20),  # Easter 2025
      Date.new(2026, 4, 12),  # Easter 2026
      Date.new(2027, 5, 2),   # Easter 2027
      Date.new(2028, 4, 16),  # Easter 2028
    ]

    easter_dates.include?(date)
  end

  # Week of month (1-4): 1=days 1-7, 2=days 8-14, 3=days 15-21, 4=days 22+
  def week_of_month(date)
    return 1 if date.day <= 7
    return 2 if date.day <= 14
    return 3 if date.day <= 21
    4
  end

  def day_of_week(date)
    date.wday
  end

  # Extended lag feature: occupancy from showtime N days ago (default 7)
  def lag_feature_for_showtime(showtime, days_ago: 7)
    return 0.0 if showtime.nil?
    target_time = showtime.start_time - days_ago.days
    historical = Showtime.where(movie_id: showtime.movie_id, hall_id: showtime.hall_id)
                         .where('start_time <= ?', target_time)
                         .order(start_time: :desc)
                         .first

    return 0.0 if historical.nil?
    cap = historical.hall.capacity.to_i
    return 0.0 if cap <= 0
    historical.tickets.where(status: %w[sold pending]).count.to_f / cap
  end

  # Rolling average occupancy for a hall over the last 7 days
  # Calculates mean occupancy (not median) to capture recent trend
  def rolling_avg_7d(hall, showtime, capacity)
    return 0.25 if showtime.nil? || capacity <= 0
    cutoff_time = showtime.start_time - 7.days
    recent_showtimes = hall.showtimes
                           .where('start_time >= ?', cutoff_time)
                           .where('start_time < ?', showtime.start_time)
                           .to_a
    return 0.25 if recent_showtimes.empty?
    
    showtime_ids = recent_showtimes.map(&:id)
    ticket_counts = Ticket.where(showtime_id: showtime_ids, status: %w[sold pending])
                          .group(:showtime_id)
                          .count
                          
    occupancies = recent_showtimes.map { |st| ticket_counts[st.id].to_i.to_f / capacity }
    occupancies.empty? ? 0.25 : occupancies.sum / occupancies.length
  end

  # ---------------------------------------------------------------------------
  # Сегментація
  # ---------------------------------------------------------------------------

  # Визначає сегмент сеансу
  def classify_segment(hour, is_weekend)
    return :weekend      if is_weekend
    return :weekday_day  if hour < 18
    :weekday_night
  end

  # Розбиває рядки на 3 сегменти
  def split_into_segments(rows)
    {
      weekday_day:   rows.select { |r| !r[:is_weekend] && r[:start_time].hour < 18 },
      weekday_night: rows.select { |r| !r[:is_weekend] && r[:start_time].hour >= 18 },
      weekend:       rows.select { |r| r[:is_weekend] }
    }
  end

  def train_segmented_models(hall_id, segmented_rows)
    SEGMENTS.each_with_object({}) do |segment, result|
      seg_rows = segmented_rows[segment]
      Rails.logger.info("FORECAST DEBUG Hall #{hall_id}: Segment #{segment} has #{seg_rows.size} rows")

      if seg_rows.size < 5
        Rails.logger.info("FORECAST DEBUG Hall #{hall_id}: Segment #{segment} too few rows — will use global fallback")
        result[segment] = { trainer: nil, model: nil }
        next
      end

      trainer = Forecasting::RegressionTrainer.new(seg_rows)
      model   = trainer.train(ridge: 0.01)
      result[segment] = { trainer: trainer, model: model }
    end
  end

  # ---------------------------------------------------------------------------
  # Мультиплікатор релізу
  # ---------------------------------------------------------------------------

  def release_multiplier_for(days_since_release)
    case days_since_release
    when 0..3   then 1.30
    when 4..7   then 1.10
    when 8..11  then 0.80
    when 12..13 then 0.65
    when 14..20 then 0.50
    else             0.35
    end
  end

  # ---------------------------------------------------------------------------
  # Збір тренувальних даних
  # ---------------------------------------------------------------------------

  def gather_training_rows_for(hall, capacity, movie_cache = {}, release_dates_cache = {})
    past_showtimes = hall.showtimes.where('start_time < ?', Time.current - 24.hours).includes(:movie).to_a

    showtime_ids = past_showtimes.map(&:id)
    return [] if showtime_ids.empty?

    ticket_counts = Ticket.where(showtime_id: showtime_ids, status: %w[sold pending]).group(:showtime_id).count

    past_showtimes.map do |showtime|
      sold_tickets = ticket_counts[showtime.id].to_i
      occupancy    = sold_tickets.to_f / capacity

      hour    = showtime.start_time.hour
      is_wknd = showtime.start_time.saturday? || showtime.start_time.sunday?
      date    = showtime.start_time.to_date

      movie_pop = cached_historical_occupancy(showtime.movie_id, movie_cache) ||
        default_occupancy_for_movie(
          showtime.movie,
          date,
          release_dates_cache,
          hour: hour,
          is_weekend: is_wknd
        )

      {
        occupancy_pct:    occupancy,
        movie_popularity: movie_pop,
        lag_feature:      lag_feature_for_showtime(showtime, days_ago: 7),
        lag_2_weeks:      lag_feature_for_showtime(showtime, days_ago: 14),
        rolling_avg_7d:   rolling_avg_7d(hall, showtime, capacity),
        start_time:       showtime.start_time,
        movie_id:         showtime.movie_id,
        hall_id:          showtime.hall_id,
        release_date:     get_movie_release_date(showtime.movie_id, release_dates_cache),
        is_weekend:       is_wknd,
        is_morning:       (hour >= 8 && hour < 12),
        is_afternoon:     (hour >= 12 && hour < 17),
        is_evening:       (hour >= 17),
        day_of_week:      day_of_week(date),
        week_of_month:    week_of_month(date),
        is_holiday:       is_holiday?(date),
        days_since_release: calculate_days_since_release(showtime.movie, date, release_dates_cache)
      }
    end
  end

  # ---------------------------------------------------------------------------
  # Історична популярність фільму
  # ---------------------------------------------------------------------------

  def calculate_historical_occupancy(movie_id)
    past_showtimes = Showtime.where(movie_id: movie_id)
                             .where('start_time < ?', Time.current - 24.hours)
                             .includes(:hall)

    return nil if past_showtimes.empty?
    showtime_ids = past_showtimes.map(&:id)
    return nil if showtime_ids.empty?
    ticket_counts = Ticket.where(showtime_id: showtime_ids, status: %w[sold pending]).group(:showtime_id).count
    occupancies = past_showtimes.filter_map do |s|
      cap = s.hall.capacity.to_i
      next if cap <= 0
      ticket_counts[s.id].to_i.to_f / cap
    end
    return nil if occupancies.empty?

    sorted = occupancies.sort
    median = sorted.length.odd? ? sorted[sorted.length / 2] : (sorted[sorted.length / 2 - 1] + sorted[sorted.length / 2]) / 2.0
    median
  end

  def cached_historical_occupancy(movie_id, cache)
    cache[movie_id] ||= calculate_historical_occupancy(movie_id)
  end

  # ---------------------------------------------------------------------------
  # Допоміжні методи
  # ---------------------------------------------------------------------------

  def get_movie_release_date(movie_id, cache)
    cache[movie_id] ||= Showtime.where(movie_id: movie_id).order(start_time: :asc).first&.start_time&.to_date
  end

  def minimum_floor_for_slot_with_day_factor(hour, is_weekend)
    if is_weekend
      return 0.10 if hour >= 8 && hour < 12
      return 0.12 if hour >= 12 && hour < 17
      return 0.15
    end

    return 0.005 if hour < 18

    0.15
  end

  def calculate_days_since_release(movie, target_date, release_dates_cache)
    return 999 if movie.nil? || target_date.nil?

    release_date = get_movie_release_date(movie.id, release_dates_cache)
    return 999 if release_date.nil?

    [(target_date - release_date).to_i, 0].max
  end

  def default_occupancy_for_movie(movie, target_date, release_dates_cache, hour: nil, is_weekend: nil)
    return 0.40 if movie.nil? || target_date.nil?

    release_date = get_movie_release_date(movie.id, release_dates_cache)
    return 0.40 if release_date.nil?

    days_since_release = (target_date - release_date).to_i

    if days_since_release >= 0 && days_since_release <= 3
      return 0.20 if !is_weekend && hour && hour < 18
      return 0.40
    end
    0.25
  end
end