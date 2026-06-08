namespace :db do
  desc 'Generate ML training data: seed historical tickets with patterns for 01.06-07.06.2026'
  task seed_ml_data: :environment do
    puts "Starting ML data seeding for 01.06-07.06.2026..."

    start_date = Date.new(2026, 6, 1)
    end_date = Date.new(2026, 6, 7)

    # Find or create a dummy workday for seeding (we need one for workday_id FK constraint)
    # Use the first cinema and first user available
    cinema = Cinema.first
    user = User.first
    
    if cinema.nil? || user.nil?
      puts "ERROR: Cannot seed data without at least one Cinema and one User in the database."
      puts "Please run db:seed first to create test data."
      return
    end

    # Create or find workdays for each day in the range
    workday_map = {}
    (start_date..end_date).each do |date|
      workday = Workday.find_or_create_by(
        user_id: user.id,
        cinema_id: cinema.id,
        start_time: date.beginning_of_day
      ) do |wd|
        wd.start_time = date.beginning_of_day
      end
      workday_map[date] = workday.id
    end

    puts "Created/found #{workday_map.count} workdays."

    showtimes = Showtime.where('DATE(start_time) >= ? AND DATE(start_time) <= ?', start_date, end_date)
                        .includes(:hall, :movie)
                        .order(:start_time)

    puts "Found #{showtimes.count} showtimes in date range."

    seeded_count = 0
    skipped_count = 0

    showtimes.each do |showtime|
      hour = showtime.start_time.hour
      is_weekend = showtime.start_time.saturday? || showtime.start_time.sunday?
      showtime_date = showtime.start_time.to_date

      # Determine expected ticket count based on time slot
      base_count = case hour
                   when 8...12  then rand(10..20)   # morning
                   when 12...17 then rand(30..45)   # afternoon
                   when 17...24 then rand(65..85)   # evening
                   else              rand(10..20)   # fallback
                   end

      # Multiply by 1.3 if weekend (convert to int, randomize within reasonable bounds)
      expected_count = is_weekend ? (base_count * 1.3).round : base_count

      # Get hall capacity and current ticket count
      capacity = showtime.hall.capacity
      already_sold = showtime.tickets.count

      # Don't exceed capacity, and leave some margin
      max_tickets = capacity - already_sold
      tickets_to_create = [expected_count, max_tickets].min

      if tickets_to_create <= 0
        puts "  [SKIP] Showtime #{showtime.id} at #{showtime.start_time} - hall capacity reached"
        skipped_count += 1
        next
      end

      # Get available seats for this showtime
      available_seats = showtime.hall.seats.where.not(
        id: showtime.tickets.pluck(:seat_id)
      ).order('RANDOM()').limit(tickets_to_create)

      if available_seats.count < tickets_to_create
        puts "  [WARN] Showtime #{showtime.id} - only #{available_seats.count} seats available, expected #{tickets_to_create}"
        tickets_to_create = available_seats.count
      end

      # Create tickets in batches
      now = Time.current
      workday_id = workday_map[showtime_date]
      
      ticket_records = available_seats.map do |seat|
        {
          showtime_id: showtime.id,
          seat_id: seat.id,
          workday_id: workday_id,
          status: 'sold',
          created_at: now,
          updated_at: now
        }
      end

      Ticket.insert_all(ticket_records) if ticket_records.any?

      time_label = case hour
                   when 8...12  then "morning"
                   when 12...17 then "afternoon"
                   when 17...24 then "evening"
                   else              "other"
                   end
      weekend_label = is_weekend ? "weekend" : "weekday"

      puts "  ✓ Showtime #{showtime.id} (#{time_label}, #{weekend_label}): created #{tickets_to_create} tickets"
      seeded_count += tickets_to_create
    end

    puts "\n=== Summary ==="
    puts "Total tickets created: #{seeded_count}"
    puts "Skipped showtimes: #{skipped_count}"
    puts "Seeding complete!"
  end
end
