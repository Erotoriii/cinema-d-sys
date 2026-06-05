class Cinema < ApplicationRecord
  belongs_to :company
  has_many :halls, dependent: :destroy
  has_many :products, dependent: :destroy
  has_many :users
  has_many :workdays, dependent: :destroy

  validates :name, :address, presence: true
  validates :company_id, presence: true
end
