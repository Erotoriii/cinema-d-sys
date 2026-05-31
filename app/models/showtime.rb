class Showtime < ApplicationRecord
  belongs_to :movie
  belongs_to :hall

  # Validations
  validates :movie_id, :hall_id, :start_time, presence: true
  validates :start_time, uniqueness: { scope: :hall_id, message: "Hall already has a showtime at this time" }
end
