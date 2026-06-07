class AddShowtimeAndMovieToForecasts < ActiveRecord::Migration[8.1]
  def change
    add_reference :forecasts, :showtime, foreign_key: true, index: true, null: true
    add_reference :forecasts, :movie, foreign_key: true, index: true, null: true
  end
end
