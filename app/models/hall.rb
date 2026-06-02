class Hall < ApplicationRecord
  belongs_to :cinema
  has_many :seats, dependent: :destroy
  has_many :showtimes, dependent: :destroy

  validates :rows, :seats_per_row, presence: true, numericality: { greater_than: 0 }
  validates :name, presence: true
  validates :cinema_id, presence: true

  after_create :generate_seats

  before_update :mark_seats_for_regeneration
  after_update :regenerate_seats_if_needed

  private

  def generate_seats
    return unless rows.present? && seats_per_row.present?

    (1..rows).each do |row|
      (1..seats_per_row).each do |number|
        seats.create(row: row, number: number, status: 'available')
      end
    end
  end

  def mark_seats_for_regeneration
    @should_regenerate_seats = rows_changed? || seats_per_row_changed?
  end

  def regenerate_seats_if_needed
    return unless @should_regenerate_seats

    seats.destroy_all
    generate_seats
  end
end
