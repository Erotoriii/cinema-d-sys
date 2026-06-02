class Workday < ApplicationRecord
  belongs_to :user
  belongs_to :cinema
  has_many :tickets, dependent: :destroy
  has_many :reports, dependent: :destroy

  validates :user_id, :cinema_id, presence: true
  validates :start_time, presence: true
end
