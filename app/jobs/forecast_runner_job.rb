class ForecastRunnerJob < ApplicationJob
  queue_as :default

  def perform(horizon_days: 7)
    run = ForecastRun.create!(run_at: Time.current, horizon_days: horizon_days, model: 'regression')
    horizon_days = horizon_days.to_i
    window_start = Time.current.beginning_of_day
    window_end = (window_start + (horizon_days - 1).days).end_of_day

    Hall.find_each do |hall|
      capacity = hall.try(:capacity)&.to_i || hall.try(:seats_count)&.to_i || hall.seats.count || 0
      next if capacity <= 0

      Rails.logger.info("FORECAST DEBUG: Processing Hall #{hall.id} with capacity #{capacity}")
      
      rows = gather_training_rows_for(hall, capacity)
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
        # Безпечно витягуємо фічі
        movie_pop = calculate_historical_occupancy(showtime.movie_id) || 0.15
        is_wknd = showtime.start_time.saturday? || showtime.start_time.sunday?
        
        hour = showtime.start_time.hour
        is_morning = (hour >= 8 && hour < 12)
        is_afternoon = (hour >= 12 && hour < 17)
        is_evening = (hour >= 17)
        slot_floor = minimum_floor_for_slot(hour)

        features = {
          movie_popularity: movie_pop,
          start_time: showtime.start_time,
          movie_id: showtime.movie_id,
          hall_id: showtime.hall_id,
          release_date: movie_release_date_for(showtime.movie),
          is_weekend: is_wknd,
          is_morning: is_morning,
          is_afternoon: is_afternoon,
          is_evening: is_evening
        }

        # Отримуємо прогноз, даємо нижню межу по слоту і верхню межу 100%
        occupancy = trainer.predict(model, features) || slot_floor
        occupancy = slot_floor if occupancy < slot_floor
        occupancy = 1.0 if occupancy > 1.0

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

  def gather_training_rows_for(hall, capacity)
    rows = []
    hall.showtimes.where('start_time < ?', Time.current).includes(:movie).find_each do |showtime|
      sold_tickets = Ticket.where(showtime_id: showtime.id).count
      occupancy = (sold_tickets.to_f / capacity)

      movie_pop = calculate_historical_occupancy(showtime.movie_id) || 0.15
      
      hour = showtime.start_time.hour
      is_morning = (hour >= 8 && hour < 12)
      is_afternoon = (hour >= 12 && hour < 17)
      is_evening = (hour >= 17)
      
      rows << {
        occupancy_pct: occupancy,
        movie_popularity: movie_pop,
        start_time: showtime.start_time,
        movie_id: showtime.movie_id,
        hall_id: showtime.hall_id,
        release_date: movie_release_date_for(showtime.movie),
        is_weekend: showtime.start_time.saturday? || showtime.start_time.sunday?,
        is_morning: is_morning,
        is_afternoon: is_afternoon,
        is_evening: is_evening
      }
    end
    rows
  end

  def calculate_historical_occupancy(movie_id)
    past_showtimes = Showtime.where(movie_id: movie_id).where('start_time < ?', Time.current).includes(:hall)
    return nil if past_showtimes.empty?

    total_capacity = past_showtimes.sum do |s| 
      s.hall.try(:capacity)&.to_i || s.hall.try(:seats_count)&.to_i || s.hall.seats.count || 0
    end
    
    return nil if total_capacity <= 0

    total_tickets = Ticket.where(showtime_id: past_showtimes.pluck(:id)).count
    
    # Виводимо в консоль, щоб ви бачили, що воно знаходить
    Rails.logger.info("FORECAST DEBUG: Фільм ID #{movie_id} | Квитків: #{total_tickets} | Місць загалом: #{total_capacity}")
    
    total_tickets.to_f / total_capacity
  end

  def movie_release_date_for(movie)
    return nil if movie.nil?

    movie.try(:release_date) || movie.created_at
  end

  def minimum_floor_for_slot(hour)
    return 0.10 if hour >= 8 && hour < 12
    return 0.12 if hour >= 12 && hour < 17

    0.15
  end
end
