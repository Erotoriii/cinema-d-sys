class Report < ApplicationRecord
  belongs_to :workday

  serialize :product_details, coder: JSON

  delegate :cinema, :user, :start_time, :end_time, to: :workday

  STATUS_LABELS = {
    "pending" => "Не переглянуто",
    "approved" => "Схвалено",
    "rejected" => "Відхилено"
  }.freeze

  enum :status, { pending: 0, approved: 1, rejected: 2 }

  validates :workday_id, presence: true
  validates :total_revenue, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :tickets_count, numericality: { greater_than_or_equal_to: 0, only_integer: true }, allow_nil: true

  after_initialize :set_default_status

  def products_rows
    Array(product_details)
  end

  def status_label
    STATUS_LABELS[status] || status.to_s.humanize
  end

  private

  def set_default_status
    self.status ||= :pending
  end
end
