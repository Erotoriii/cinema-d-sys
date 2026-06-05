class Workday < ApplicationRecord
  belongs_to :user
  belongs_to :cinema
  has_many :tickets, dependent: :destroy
  has_one :report, dependent: :destroy

  validates :user_id, :cinema_id, presence: true
  validates :start_time, presence: true

  def close_shift!
    Workday.transaction do
      sold_tickets = tickets.where(status: %w[sold Sold])

      total_revenue = sold_tickets.joins(:showtime).sum('showtimes.price') || BigDecimal('0')
      tickets_count = sold_tickets.count

      report = Report.create!(
        workday_id: id,
        total_revenue: total_revenue,
        tickets_count: tickets_count,
        total_sales: bar_sales_total,
        status: :pending
      )

      self.update!(end_time: Time.current)
      report
    end
  rescue StandardError => e
    Rails.logger.error("Failed to close shift #{id}: #{e.class} - #{e.message}")
    raise e
  end
end
