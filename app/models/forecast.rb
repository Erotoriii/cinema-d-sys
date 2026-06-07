class Forecast < ApplicationRecord
  belongs_to :forecast_run
  belongs_to :hall
  belongs_to :showtime, optional: true
  belongs_to :movie, optional: true

  validates :showtime_at, presence: true

  def predicted_fill_pct
    return nil if predicted_tickets.nil? || hall.nil?
    capacity = (hall.rows.to_i * hall.seats_per_row.to_i)
    return nil if capacity.zero?
    ((predicted_tickets.to_d / BigDecimal(capacity.to_s)) * 100).to_f
  end
end
