class Seat < ApplicationRecord
  belongs_to :hall
  has_many :tickets, dependent: :destroy

  validates :row, :number, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true, inclusion: { in: %w(available occupied reserved), message: "%{value} is not a valid status" }
  validates :hall_id, presence: true
  validates :row, :number, uniqueness: { scope: :hall_id, message: "combination must be unique within a hall" }
end
