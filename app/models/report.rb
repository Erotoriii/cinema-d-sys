class Report < ApplicationRecord
  belongs_to :workday

  validates :workday_id, presence: true
  validates :status, presence: true, inclusion: { in: %w(pending submitted approved rejected), message: "%{value} is not a valid status" }
end
