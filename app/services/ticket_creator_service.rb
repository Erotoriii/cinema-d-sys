class TicketCreatorService
  attr_reader :created_count, :errors

  def initialize(showtime:, seat_ids:, workday:, current_user:)
    @showtime = showtime
    @seat_ids = seat_ids
    @workday = workday
    @current_user = current_user
    @created_count = 0
    @errors = []
    @sold_tickets = []
  end

  def call
    validate_permissions!
    create_tickets
    { created_count: created_count, errors: errors, sold_tickets: @sold_tickets }
  end

  private

  attr_reader :showtime, :seat_ids, :workday, :current_user

  def validate_permissions!
    return if showtime.start_time >= Time.current || current_user.admin_or_manager?

    raise PermissionDenied, "Тільки адміністратор може додавати квитки до минулих сеансів."
  end

  def create_tickets
    seat_ids.each do |seat_id|
      create_ticket_for_seat(seat_id)
    end
  rescue StandardError => e
    Rails.logger.error "Unexpected error in ticket creation: #{e.message}"
    errors << "Помилка системи: #{e.message}"
  end

  def create_ticket_for_seat(seat_id)
    ticket = Ticket.find_or_initialize_by(showtime_id: showtime.id, seat_id: seat_id)
    update_attrs = { status: 'sold' }
    update_attrs[:workday_id] = workday.id if workday

    ticket.update!(update_attrs)
    if ticket.persisted?
      @created_count += 1
      @sold_tickets << ticket
      Rails.logger.info "Ticket saved for seat #{seat_id}"
    end
  rescue ActiveRecord::RecordInvalid => e
    error_msg = e.record.errors.full_messages.join(', ')
    Rails.logger.error "TICKET SAVE ERROR for seat #{seat_id}: #{error_msg}"
    errors << "Seat #{seat_id}: #{error_msg}"
  end

  class PermissionDenied < StandardError; end
end
