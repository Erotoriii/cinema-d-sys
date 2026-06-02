class Ticket < ApplicationRecord
  belongs_to :showtime
  belongs_to :seat
  belongs_to :workday

  validates :status, presence: true
  validates :showtime_id, :seat_id, :workday_id, presence: true
  validates :seat_id, uniqueness: { scope: :showtime_id, message: "is already booked for this showtime" }
end
