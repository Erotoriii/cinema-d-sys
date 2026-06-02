class Movie < ApplicationRecord
  has_many :showtimes, dependent: :destroy

  validates :title, presence: true
  validates :duration, presence: true, numericality: { greater_than: 0 }
end
