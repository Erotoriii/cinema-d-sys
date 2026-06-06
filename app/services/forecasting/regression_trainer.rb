require 'matrix'

module Forecasting
  class RegressionTrainer
    # rows: array of hashes with keys :sold, :dow, :hour, :capacity, :movie_popularity, :is_weekend, :days_since_release
    def initialize(rows)
      @rows = rows.map do |r|
        {
          sold: r[:sold].to_f,
          dow: r[:dow].to_f,
          hour: r[:hour].to_f,
          capacity: r[:capacity].to_f,
          movie_popularity: r[:movie_popularity].to_f,
          is_weekend: (r[:is_weekend] ? 1.0 : 0.0),
          days_since_release: (r[:days_since_release] || 0).to_f
        }
      end
    end

    # ridge: regularization strength (lambda). If nil or 0 -> plain OLS
    def train(ridge: 1.0)
      return nil if @rows.size < 6

      x_rows = @rows.map do |r|
        [1.0, r[:dow], r[:hour], r[:capacity], r[:movie_popularity], r[:is_weekend], r[:days_since_release]]
      end
      y_vec = Vector.elements(@rows.map { |r| r[:sold] })

      x = Matrix.rows(x_rows)
      xt = x.transpose

      xtx = xt * x

      # regularize: add ridge lambda to diagonal (excluding intercept term at index 0)
      if ridge && ridge.to_f != 0.0
        ridge_val = ridge.to_f
        mat = xtx.to_a
        (0...mat.size).each do |i|
          mat[i][i] += (i == 0 ? 0.0 : ridge_val)
        end
        xtx = Matrix.rows(mat)
      end

      begin
        beta = xtx.inverse * xt * y_vec
      rescue StandardError
        return nil
      end

      beta.to_a
    end

    def predict(coefs, features)
      return nil if coefs.nil?
      vec = [1.0, features[:dow].to_f, features[:hour].to_f, features[:capacity].to_f, features[:movie_popularity].to_f, (features[:is_weekend] ? 1.0 : 0.0), (features[:days_since_release] || 0).to_f]
      vec.zip(coefs).map { |a, b| a * b.to_f }.sum
    end
  end
end
