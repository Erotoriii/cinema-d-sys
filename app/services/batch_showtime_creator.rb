class BatchShowtimeCreator
  def initialize(movie_id:, hall_id:, start_date:, end_date:, schedule_text:, base_price:)
    @movie_id = movie_id
    @hall_id = hall_id
    @start_date = parse_date(start_date)
    @end_date = parse_date(end_date)
    @schedule_text = schedule_text.to_s
    @base_price = parse_decimal(base_price)
  end

  def call
    validate_inputs!

    created_count = 0

    ActiveRecord::Base.transaction do
      date_range.each do |date|
        parsed_schedule.each do |entry|
          Showtime.create!(
            movie_id: movie_id,
            hall_id: hall_id,
            start_time: Time.zone.parse("#{date} #{entry[:time]}"),
            price: entry[:price] || base_price
          )
          created_count += 1
        end
      end
    end

    { created_count: created_count }
  end

  private

  attr_reader :movie_id, :hall_id, :start_date, :end_date, :schedule_text, :base_price

  def validate_inputs!
    raise ArgumentError, "Movie is required." if movie_id.blank?
    raise ArgumentError, "Hall is required." if hall_id.blank?
    raise ArgumentError, "Start date is required." if start_date.blank?
    raise ArgumentError, "End date is required." if end_date.blank?
    raise ArgumentError, "End date must be on or after start date." if end_date < start_date
    raise ArgumentError, "Schedule text is required." if schedule_text.blank?
    raise ArgumentError, "Base price is required." if base_price.blank?
    raise ArgumentError, "Schedule must include at least one valid time." if parsed_schedule.empty?
  end

  def parsed_schedule
    @parsed_schedule ||= schedule_text.each_line.filter_map do |line|
      token = line.strip
      next if token.blank?

      time_text, price_text = token.split("|", 2)
      time_text = time_text.to_s.strip
      parsed_time = parse_time_of_day(time_text)
      next if parsed_time.blank?

      {
        time: parsed_time,
        price: parse_price(price_text)
      }
    end
  end

  def date_range
    start_date..end_date
  end

  def parse_date(value)
    return value if value.is_a?(Date)

    Date.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def parse_decimal(value)
    return value if value.is_a?(Numeric)

    value.to_s.tr(",", ".").to_d if value.present?
  end

  def parse_price(value)
    return base_price if value.blank?

    value.to_s.gsub(/[^\d.,]/, "").tr(",", ".").to_d
  end

  def parse_time_of_day(value)
    return if value.blank?

    time = Time.zone.parse("#{start_date} #{value}")
    time&.strftime("%H:%M")
  rescue ArgumentError, TypeError
    nil
  end
end