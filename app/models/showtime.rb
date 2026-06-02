class Showtime < ApplicationRecord
  belongs_to :movie
  belongs_to :hall
  has_many :tickets, dependent: :destroy

  validates :movie_id, :hall_id, :start_time, presence: true
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :start_time, uniqueness: { scope: :hall_id, message: "Hall already has a showtime at this time" }
end
