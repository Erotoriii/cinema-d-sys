class ForecastRunnerJob < ApplicationJob
  queue_as :default

  def perform(horizon_days: 7)
    run = ForecastRun.create!(run_at: Time.current, horizon_days: horizon_days, model: 'regression')

    Hall.find_each do |hall|
      capacity = hall.try(:capacity)&.to_i || hall.try(:seats_count)&.to_i || hall.seats.count || 0
      next if capacity <= 0

      rows = gather_training_rows_for(hall, capacity)
      next if rows.empty?

      trainer = Forecasting::RegressionTrainer.new(rows)
      model = trainer.train(ridge: 1.0)
      
      upcoming_showtimes = hall.showtimes.where('start_time >= ? AND start_time <= ?', Time.current, Time.current + horizon_days.days)

      upcoming_showtimes.each do |showtime|
        # Безпечно витягуємо фічі
        movie_pop = calculate_historical_occupancy(showtime.movie_id) || 0.15
        days_release = [(showtime.start_time.to_date - (showtime.movie.created_at&.to_date || Date.today)).to_i, 0].max
        is_wknd = showtime.start_time.saturday? || showtime.start_time.sunday? ? 1.0 : 0.0
        is_eve = showtime.start_time.hour >= 18 ? 1.0 : 0.0

        features = {
          movie_popularity: movie_pop,
          days_since_release: days_release,
          is_weekend: is_wknd,
          is_evening: is_eve
        }

        # Отримуємо прогноз, не даємо впасти нижче 15% або піднятися вище 100%
        occupancy = trainer.predict(model, features) || 0.15
        occupancy = 0.15 if occupancy < 0.15
        occupancy = 1.0 if occupancy > 1.0

        predicted_tickets = (occupancy * capacity).round

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
      days_release = [(showtime.start_time.to_date - (showtime.movie.created_at&.to_date || Date.today)).to_i, 0].max
      
      rows << {
        occupancy_pct: occupancy,
        movie_popularity: movie_pop,
        days_since_release: days_release,
        is_weekend: showtime.start_time.saturday? || showtime.start_time.sunday? ? 1.0 : 0.0,
        is_evening: showtime.start_time.hour >= 18 ? 1.0 : 0.0
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
end
