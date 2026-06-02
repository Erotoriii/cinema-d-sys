class Company < ApplicationRecord
  has_many :cinemas, dependent: :destroy

  validates :name, presence: true
end
