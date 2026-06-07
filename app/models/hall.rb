class Hall < ApplicationRecord
  belongs_to :cinema
  has_many :seats, dependent: :destroy
  has_many :showtimes, dependent: :destroy

  validates :rows, :seats_per_row, presence: true, numericality: { greater_than: 0 }
  validates :name, presence: true
  validates :cinema_id, presence: true

  after_create_commit :generate_seats

  after_update_commit :regenerate_seats_if_needed

  def capacity
    (rows || 0) * (seats_per_row || 0)
  end

  private

  def generate_seats
    return unless rows.present? && seats_per_row.present?

    now = Time.current
    seat_rows = []

    (1..rows.to_i).each do |row|
      (1..seats_per_row.to_i).each do |number|
        seat_rows << {
          hall_id: id,
          row: row,
          number: number,
          status: 'available',
          created_at: now,
          updated_at: now
        }
      end
    end

    Seat.insert_all(seat_rows) if seat_rows.any?
  end

  def regenerate_seats_if_needed
    return unless previous_changes.key?('rows') || previous_changes.key?('seats_per_row')

    rebuild_seats!
  end

  def rebuild_seats!
    seats.delete_all
    generate_seats
  end
end
