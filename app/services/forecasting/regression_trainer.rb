require 'matrix'

module Forecasting
  class RegressionTrainer
    # rows: array of hashes with keys :occupancy_pct, :movie_popularity, :days_since_release, :is_weekend, :is_evening
    # occupancy_pct must be a float between 0.0 and 1.0 (not 0-100)
    def initialize(rows)
      @rows = rows.map do |r|
        {
          occupancy_pct: r[:occupancy_pct].to_f,
          movie_popularity: r[:movie_popularity].to_f,
          days_since_release: (r[:days_since_release] || 0).to_f,
          is_weekend: (r[:is_weekend] ? 1.0 : 0.0),
          is_evening: (r[:is_evening] ? 1.0 : 0.0)
        }
      end
    end

    # ridge: regularization strength (lambda). If nil or 0 -> plain OLS
    def train(ridge: 1.0)
      # Minimal data requirement
      return nil if @rows.size < 6

      feature_names = %i[movie_popularity days_since_release is_weekend is_evening]

      x_raw = @rows.map do |r|
        feature_names.map { |k| r[k].to_f }
      end
      y = Vector.elements(@rows.map { |r| r[:occupancy_pct] })

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
      # features expected: movie_popularity, days_since_release, is_weekend, is_evening
      vec = [1.0,
             features[:movie_popularity].to_f,
             (features[:days_since_release] || 0).to_f,
             (features[:is_weekend] ? 1.0 : 0.0),
             (features[:is_evening] ? 1.0 : 0.0)]
      vec.zip(coefs).map { |a, b| a * b.to_f }.sum
    end
  end
end
