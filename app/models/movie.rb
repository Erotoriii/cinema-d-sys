class Movie < ApplicationRecord
  has_many :showtimes, dependent: :destroy
  belongs_to :company, optional: true

  validates :title, presence: true
  validates :duration, presence: true, numericality: { greater_than: 0 } 
end
