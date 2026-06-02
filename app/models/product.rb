class Product < ApplicationRecord
  belongs_to :cinema

  validates :name, presence: true
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :amount, :sold_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :cinema_id, presence: true
end
