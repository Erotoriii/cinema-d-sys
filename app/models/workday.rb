class Workday < ApplicationRecord
  belongs_to :user
  belongs_to :cinema
  has_many :tickets, dependent: :destroy
  has_one :report, dependent: :destroy

  serialize :product_snapshot, coder: JSON

  validates :user_id, :cinema_id, presence: true
  validates :start_time, presence: true

  def capture_product_snapshot!
    self.product_snapshot = cinema.products.order(:created_at).map do |product|
      {
        "id" => product.id,
        "name" => product.name,
        "price" => product.price.to_d.to_s,
        "amount" => product.amount.to_i,
        "sold_amount" => product.sold_amount.to_i
      }
    end
  end

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
        product_details: build_product_details,
        status: :pending
      )

      self.update!(end_time: Time.current)
      report
    end
  rescue StandardError => e
    Rails.logger.error("Failed to close shift #{id}: #{e.class} - #{e.message}")
    raise e
  end

  def build_product_details
    snapshot_by_id = Array(product_snapshot).index_by { |item| item["id"].to_i }

    cinema.products.order(:created_at).map do |product|
      snapshot = snapshot_by_id[product.id] || {}
      starting_sold_amount = snapshot["sold_amount"].to_i
      sold_qty = [product.sold_amount.to_i - starting_sold_amount, 0].max
      unit_price = BigDecimal(snapshot["price"].to_s.presence || product.price.to_s)

      {
        "name" => snapshot["name"].presence || product.name,
        "amount" => product.amount.to_i,
        "income" => (sold_qty * unit_price).to_s("F"),
        "sold" => sold_qty,
        "unit_price" => unit_price.to_s("F")
      }
    end
  end
end
