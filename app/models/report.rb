class Report < ApplicationRecord
  belongs_to :workday

  enum :status, { pending: 0, approved: 1, rejected: 2 }

  validates :workday_id, presence: true
  validates :total_revenue, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :tickets_count, numericality: { greater_than_or_equal_to: 0, only_integer: true }, allow_nil: true

  after_initialize :set_default_status

  private

  def set_default_status
    self.status ||= :pending
  end
end
