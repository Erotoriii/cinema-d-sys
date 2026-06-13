class TicketUpdateService
  def initialize(ticket, params)
    @ticket = ticket
    @params = params
    @old_status = ticket.status
    @old_seat_id = ticket.seat_id
  end

  def update!
    return { success: false, errors: @ticket.errors.full_messages } unless @ticket.update(@params)

    {
      success: true,
      message: build_success_message,
      new_status: determine_new_status
    }
  end

  private

  def build_success_message
    message = "Ticket updated successfully"

    new_seat_id = @params[:seat_id]
    if @old_seat_id != new_seat_id && new_seat_id.present?
      old_seat = Seat.find(@old_seat_id)
      new_seat = Seat.find(new_seat_id)
      message += ": seat changed from Row #{old_seat.row}, Seat #{old_seat.number} to Row #{new_seat.row}, Seat #{new_seat.number}"
    end

    new_status = @params[:status]
    if @old_status != new_status
      message += ", status changed from #{@old_status} to #{new_status}"
    end

    message
  end

  def determine_new_status
    new_seat_id = @params[:seat_id]
    (@old_seat_id != new_seat_id && new_seat_id.present?) ? 'moved' : @params[:status]
  end
end
