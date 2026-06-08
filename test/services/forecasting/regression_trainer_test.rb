require 'test_helper'
require 'json'

class Forecasting::RegressionTrainerTest < Minitest::Test
  def test_train_returns_model_structure_and_predicts
    company = Company.create!(name: 'Test Company', domain_prefix: "test#{Time.now.to_i}")
    cinema = Cinema.create!(name: 'Test Cinema', company: company, address: 'Main St')
    user = User.create!(email: "tester#{Time.now.to_i}@example.com", password: 'password123', role: 'staff', company: company, cinema: cinema)
    hall = Hall.create!(name: 'Hall 1', cinema: cinema, rows: 2, seats_per_row: 10)
    movie = Movie.create!(title: 'Test Movie', duration: 120, company: company)
    workday = Workday.create!(user: user, cinema: cinema, start_time: Time.current)

    base_time = Time.zone.local(2026, 6, 1, 19, 0, 0)
    rows = []

    7.times do |i|
      showtime = Showtime.create!(movie: movie, hall: hall, start_time: base_time + (i * 7).days, price: 12.5)
      sold_count = 10 + i

      sold_count.times do |ticket_index|
        Ticket.create!(seat: hall.seats[ticket_index], showtime: showtime, workday: workday, status: 'sold')
      end

      rows << {
        occupancy_pct: sold_count.to_f / 100.0,
        movie_popularity: 0.2 + (i * 0.05),
        start_time: showtime.start_time,
        movie_id: movie.id,
        hall_id: hall.id,
        release_date: base_time.to_date - 21,
        is_weekend: showtime.start_time.saturday? || showtime.start_time.sunday?,
        is_evening: true
      }
    end

    trainer = Forecasting::RegressionTrainer.new(rows)
    model = trainer.train(ridge: 1.0)

    assert model && model[:coefs].is_a?(Array), "Expected model to be present"
    assert_equal 8, model[:coefs].size, "coefs should include intercept + 7 features"
    assert_equal %w[movie_popularity days_since_release lag_feature is_weekend is_morning is_afternoon is_evening], model[:feature_names]

    sample = {
      movie_popularity: 0.5,
      start_time: base_time + (7 * 7).days,
      movie_id: movie.id,
      hall_id: hall.id,
      release_date: base_time.to_date - 21,
      is_weekend: false,
      is_evening: true
    }
    pred = trainer.predict(model, sample)
    assert pred.is_a?(Numeric), "Prediction should be numeric"
  end
end
