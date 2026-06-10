require 'matrix'

module Forecasting
  class RegressionTrainer
    # rows: array of hashes with keys :occupancy_pct, :movie_popularity, :start_time, :movie_id, :hall_id, :release_date, :is_weekend, :is_morning, :is_afternoon, :is_evening
    # occupancy_pct must be a float between 0.0 and 1.0 (not 0-100)
    def initialize(rows)
      @rows = rows
    end

    # ridge: regularization strength (lambda). If nil or 0 -> plain OLS
    def train(ridge: 1.0)
      # Minimal data requirement
      return nil if @rows.size < 6

      feature_names = self.class.feature_names

      x_raw = @rows.map do |row|
        feature_vector(row).values_at(*feature_names)
      end
      y = Vector.elements(@rows.map { |r| r[:occupancy_pct].to_f })

      # standardize features (mean/std)
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

      # reassemble rows with intercept
      x_rows = x_std.transpose.map { |r| [1.0] + r }

      x = Matrix.rows(x_rows)
      xt = x.transpose

      xtx = xt * x

      # regularize diagonal excluding intercept
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
      rescue StandardError
        return nil
      end

      # Convert standardized coefs back to original scale
      # beta_std corresponds to intercept + standardized feature coefs
      intercept = beta_std[0]
      coefs = [intercept]
      beta_std.to_a[1..-1].each_with_index do |b, idx|
        # original coef = b / std
        coefs << (b.to_f / stds[idx])
      end

      # Adjust intercept to account for means/stds: intercept_orig = intercept - sum(coef_i * mean_i)
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
      feature_vector = feature_vector(features)
      vec = [1.0] + self.class.feature_names.map { |name| feature_vector[name].to_f }
      vec.zip(coefs).map { |a, b| a * b.to_f }.sum
    end

    def self.feature_names
      %i[movie_popularity days_since_release lag_feature is_weekend is_morning is_afternoon is_evening]
    end

    private

    def feature_vector(row)
      row = row || {}

      {
        movie_popularity: row[:movie_popularity].to_f,
        days_since_release: days_since_release_for(row),
        lag_feature: lag_feature_for(row),
        is_weekend: flag_value(row[:is_weekend]),
        is_morning: flag_value(row[:is_morning]),
        is_afternoon: flag_value(row[:is_afternoon]),
        is_evening: flag_value(row[:is_evening])
      }
    end

    def flag_value(value)
      return 0.0 if value.nil?
      return 1.0 if value == true
      return 0.0 if value == false

      return value.to_f > 0.0 ? 1.0 : 0.0 if value.is_a?(Numeric)

      normalized = value.to_s.strip.downcase
      return 1.0 if %w[1 true t yes y].include?(normalized)

      0.0
    end

    def days_since_release_for(row)
      start_time = row[:start_time]
      release_date = row[:release_date] || movie_release_date_for(row[:movie_id])

      return (row[:days_since_release] || 0).to_f if start_time.blank? || release_date.blank?

      [(start_time.to_date - release_date.to_date).to_i, 0].max.to_f
    end

    def movie_release_date_for(movie_id)
      return nil if movie_id.blank?

      movie = Movie.find_by(id: movie_id)
      return nil if movie.nil?

      movie.try(:release_date) || movie.created_at
    end

    def lag_feature_for(row)
      return (row[:lag_feature] || 0).to_f if row[:lag_feature]

      start_time = row[:start_time]
      movie_id = row[:movie_id]
      hall_id = row[:hall_id]

      return 0.0 if start_time.blank? || movie_id.blank? || hall_id.blank?

      target_time = start_time - 7.days
      historical_showtime = Showtime.where(movie_id: movie_id, hall_id: hall_id)
                                    .where('start_time <= ?', target_time)
                                    .order(start_time: :desc)
                                    .first

      return 0.0 unless historical_showtime

      hall_capacity = historical_showtime.hall&.capacity.to_i
      return 0.0 if hall_capacity <= 0

      sold_tickets = historical_showtime.tickets.where(status: %w[sold Sold]).count
      sold_tickets.to_f / hall_capacity
    end
  end
end
