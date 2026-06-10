class Showtime < ApplicationRecord
  belongs_to :movie
  belongs_to :hall
  has_many :tickets, dependent: :destroy
  has_many :forecasts, dependent: :destroy

  attr_accessor :batch_date, :batch_times_text

  validates :movie_id, :hall_id, :start_time, presence: true
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :start_time, uniqueness: { scope: :hall_id, message: "Hall already has a showtime at this time" }
  validate :does_not_overlap_with_existing_showtime

  def overlaps_with?(other)
    return false if other.nil? || start_time.blank? || other.start_time.blank?
    return false if movie.blank? || movie.duration.blank? || other.movie.blank? || other.movie.duration.blank?

    start_a = start_time
    end_a = start_a + movie.duration.minutes
    start_b = other.start_time
    end_b = start_b + other.movie.duration.minutes

    start_a < end_b && start_b < end_a
  end

  private

  def does_not_overlap_with_existing_showtime
    return if hall_id.blank? || start_time.blank? || movie.blank? || movie.duration.blank?

    conflict = Showtime.includes(:movie)
                       .where(hall_id: hall_id)
                       .where.not(id: id)
                       .detect { |showtime| overlaps_with?(showtime) }

    return if conflict.blank?

    errors.add(:start_time, "конфліктує з існуючим сеансом у цьому залі: #{conflict.movie&.title} о #{conflict.start_time.strftime('%d/%m %H:%M')}")
  end
end
