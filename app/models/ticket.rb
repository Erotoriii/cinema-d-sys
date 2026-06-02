class Ticket < ApplicationRecord
  belongs_to :showtime
  belongs_to :seat
  belongs_to :workday, optional: true

  validates :status, presence: true, inclusion: { in: %w(sold pending cancelled), message: "%{value} is not a valid status" }
  validates :showtime_id, :seat_id, presence: true
  validates :seat_id, uniqueness: { scope: :showtime_id, message: "is already booked for this showtime" }
end
