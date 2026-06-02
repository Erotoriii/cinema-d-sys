class Company < ApplicationRecord
  has_many :users
  has_many :movies
  has_many :cinemas, dependent: :destroy

  validates :domain_prefix, presence: true, uniqueness: true, format: { with: /\A[a-z0-9]+\z/, message: "дозволені лише малі латинські літери та цифри" }
end
