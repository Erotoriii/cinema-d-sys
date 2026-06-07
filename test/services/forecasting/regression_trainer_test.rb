require 'test_helper'
require 'json'

class Forecasting::RegressionTrainerTest < Minitest::Test
  def test_train_returns_model_structure_and_predicts
    rows = []
    10.times do |i|
      rows << {
        sold: 20 + i * 2 + (i.even? ? 5 : 0),
        movie_popularity: 10 + i * 3,
        days_since_release: [1, 5, 10, 20, 30][i % 5],
        is_weekend: (i % 6 == 0),
        is_evening: (i % 3 == 0)
      }
    end

    trainer = Forecasting::RegressionTrainer.new(rows)
    model = trainer.train(ridge: 1.0)

    assert model && model[:coefs].is_a?(Array), "Expected model to be present"
    assert_equal 5, model[:coefs].size, "coefs should include intercept + 4 features"

    sample = { movie_popularity: 40.0, days_since_release: 7, is_weekend: false, is_evening: true }
    pred = trainer.predict(model, sample)
    assert pred.is_a?(Numeric), "Prediction should be numeric"
  end
end
