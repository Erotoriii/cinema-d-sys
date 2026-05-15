class Hall < ApplicationRecord
  belongs_to :cinema
  has_many :seats, dependent: :destroy

  # Validate that rows and seats_per_row are present
  validates :rows, :seats_per_row, presence: true, numericality: { greater_than: 0 }

  # After creating a hall, generate seats
  after_create :generate_seats

  # When updating, regenerate seats if dimensions changed
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

    # Delete old seats and generate new ones
    seats.destroy_all
    generate_seats
  end
end
