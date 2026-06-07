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

require 'matrix'

module Forecasting
  class RegressionTrainer
    # rows: масив хешів з ключами :occupancy_pct, :movie_popularity, :days_since_release, :is_weekend, :is_evening
    def initialize(rows)
      @rows = rows.map do |r|
        {
          occupancy_pct: r[:occupancy_pct].to_f,
          movie_popularity: r[:movie_popularity].to_f,
          days_since_release: (r[:days_since_release] || 0).to_f,
          is_weekend: (r[:is_weekend] == 1.0 || r[:is_weekend] == 1 ? 1.0 : 0.0),
          is_evening: (r[:is_evening] == 1.0 || r[:is_evening] == 1 ? 1.0 : 0.0)
        }
      end
    end

    def train(ridge: 1.0)
      # ВИПРАВЛЕНО: Зменшено ліміт до 2 для тестування (було 6)
      return nil if @rows.size < 2

      feature_names = %i[movie_popularity days_since_release is_weekend is_evening]

      x_raw = @rows.map do |r|
        feature_names.map { |k| r[k].to_f }
      end
      y = Vector.elements(@rows.map { |r| r[:occupancy_pct] })

      # Стандартизація фіч
      means = []
      stds = []
      x_std = x_raw.transpose.map do |col|
        col = col.map(&:to_f)
        mean = col.sum / col.size
        variance = col.map { |v| (v - mean) ** 2 }.sum / col.size
        std = Math.sqrt(variance)
        std = 1.0 if std == 0.0
        means << mean
        stds << std
        col.map { |v| (v - mean) / std }
      end

      # Додаємо intercept (вільний член)
      x_rows = x_std.transpose.map { |r| [1.0] + r }

      x = Matrix.rows(x_rows)
      xt = x.transpose

      xtx = xt * x

      # Регуляризація Ridge
      if ridge && ridge.to_f != 0.0
        ridge_val = ridge.to_f
        mat = xtx.to_a
        (0...mat.size).each do |i|
          mat[i][i] += (i == 0 ? 0.0 : ridge_val)
        end
        xtx = Matrix.rows(mat)
      end

      begin
        beta_std = xtx.inverse * xt * y
      rescue StandardError => e
        Rails.logger.error("FORECAST ERROR: Помилка матриці - #{e.message}")
        return nil
      end

      # Конвертація стандартизованих коефіцієнтів назад
      intercept = beta_std[0]
      coefs = [intercept]
      beta_std.to_a[1..-1].each_with_index do |b, idx|
        coefs << (b.to_f / stds[idx])
      end

      intercept_adj = coefs[0].to_f
      coefs[1..-1].each_with_index do |coef, idx|
        intercept_adj -= coef.to_f * means[idx]
      end
      coefs[0] = intercept_adj

      { feature_names: feature_names.map(&:to_s), coefs: coefs, means: means, stds: stds }
    end

    def predict(model, features)
      return nil if model.nil? || model[:coefs].nil?
      coefs = model[:coefs]
      
      vec = [1.0,
             features[:movie_popularity].to_f,
             (features[:days_since_release] || 0).to_f,
             (features[:is_weekend] == 1.0 || features[:is_weekend] == 1 ? 1.0 : 0.0),
             (features[:is_evening] == 1.0 || features[:is_evening] == 1 ? 1.0 : 0.0)]
             
      vec.zip(coefs).map { |a, b| a * b.to_f }.sum
    end
  end
end