class TicketsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_ticket, only: [:show, :edit, :update, :destroy]
  before_action :require_active_workday, only: [:create, :update, :destroy]

  # GET /tickets/new?showtime_id=:showtime_id
  def new
    @showtime = Showtime.find(params[:showtime_id])
    @hall = @showtime.hall
    @seats = @hall.seats.order(:row, :number)
    # Only count sold and pending tickets as occupied, cancelled tickets make seats available again
    @sold_seat_ids = Ticket.where(showtime_id: @showtime.id).where(status: ['sold', 'pending']).pluck(:seat_id)
    @movie = @showtime.movie
    
    # Get all tickets for this showtime with their status
    @tickets_by_seat = Ticket.where(showtime_id: @showtime.id).index_by(&:seat_id)

    @latest_forecast_for_showtime = Forecast
      .joins(:forecast_run)
      .includes(:forecast_run)
      .where(showtime_id: @showtime.id)
      .order('forecast_runs.run_at DESC')
      .first

    if @latest_forecast_for_showtime.present?
      @predicted_occupancy_pct = @latest_forecast_for_showtime.predicted_fill_pct.to_f
      @predicted_tickets_count = @latest_forecast_for_showtime.predicted_tickets.to_f.round
      @forecast_generated_at = @latest_forecast_for_showtime.forecast_run&.run_at
    end
  end

  # POST /tickets
  def create
    Rails.logger.debug "=== TICKET CREATE DEBUG ==="
    Rails.logger.debug "params: #{params.inspect}"
    Rails.logger.debug "tickets_params: #{tickets_params.inspect}"
    
    showtime_id = tickets_params[:showtime_id]
    seat_ids = tickets_params[:seat_ids] || []

    Rails.logger.debug "showtime_id: #{showtime_id.inspect}"
    Rails.logger.debug "seat_ids: #{seat_ids.inspect}"
    Rails.logger.debug "current_workday: #{current_workday.inspect}"

    # Validate showtime_id and seat_ids
    if showtime_id.blank?
      flash[:alert] = "ERROR: showtime_id is missing from params"
      redirect_to root_path
      return
    end

    showtime = Showtime.find(showtime_id)

    if showtime.start_time < Time.current && !current_user.admin?
      flash[:alert] = "Тільки адміністратор може додавати квитки до минулих сеансів."
      redirect_to new_ticket_path(showtime_id: showtime_id)
      return
    end

    if seat_ids.empty?
      flash[:alert] = "Please select at least one seat."
      redirect_to new_ticket_path(showtime_id: showtime_id)
      return
    end

    # Track created tickets and errors
    created_count = 0
    errors = []

    seat_ids.each do |seat_id|
      ticket = Ticket.find_or_initialize_by(showtime_id: showtime_id, seat_id: seat_id)

      Rails.logger.debug "Creating ticket: #{ticket.inspect}"

      ticket.update!(status: 'sold', workday_id: current_workday.id)
      if ticket.persisted?
        Rails.logger.info "Ticket saved for seat #{seat_id}"
        created_count += 1
      end
    rescue ActiveRecord::RecordInvalid => e
      error_msg = e.record.errors.full_messages.join(', ')
      Rails.logger.error "TICKET SAVE ERROR for seat #{seat_id}: #{error_msg}"
      errors << "Seat #{seat_id}: #{error_msg}"
    end

    Rails.logger.debug "=== TICKET CREATE SUMMARY ==="
    Rails.logger.debug "Created: #{created_count}, Errors: #{errors.count}"

    # Build notification message
    if created_count > 0
      notice = "#{created_count} ticket(s) sold successfully"
      notice += " (Errors: #{errors.join(', ')})" if errors.any?
      flash[:notice] = notice
    elsif errors.any?
      flash[:alert] = "No tickets sold. #{errors.join(', ')}"
    else
      flash[:alert] = "No seats selected."
    end

    # CRITICAL: Always redirect back to the seat map
    redirect_to new_ticket_path(showtime_id: showtime_id)
  end

  # GET /tickets/:id
  def show
  end

  # GET /tickets/:id/edit
  def edit
    hall = @ticket.showtime.hall
    sold_seat_ids = @ticket.showtime.tickets.where.not(id: @ticket.id).pluck(:seat_id)
    @available_seats = hall.seats.where.not(id: sold_seat_ids).order(:row, :number)
    
    # When called via AJAX, render without layout
    render layout: false if request.xhr?
  end

  # PATCH/PUT /tickets/:id
  def update
    Rails.logger.debug "=== TICKET UPDATE DEBUG ==="
    Rails.logger.debug "params: #{params.inspect}"
    Rails.logger.debug "ticket_update_params: #{ticket_update_params.inspect}"
    
    old_status = @ticket.status
    old_seat_id = @ticket.seat_id
    new_status = ticket_update_params[:status]
    new_seat_id = ticket_update_params[:seat_id]

    Rails.logger.debug "Updating ticket #{@ticket.id} from status #{old_status} to #{new_status}"

    if @ticket.update(ticket_update_params)
      message = "Ticket updated successfully"
      
      if old_seat_id != new_seat_id && new_seat_id.present?
        old_seat = Seat.find(old_seat_id)
        new_seat = Seat.find(new_seat_id)
        message += ": seat changed from Row #{old_seat.row}, Seat #{old_seat.number} to Row #{new_seat.row}, Seat #{new_seat.number}"
      end
      
      if old_status != new_status
        message += ", status changed from #{old_status} to #{new_status}"
      end
      
      Rails.logger.debug "Update successful: #{message}"
      
      respond_to do |format|
        format.json { render json: { success: true, message: message, new_status: new_seat_id != old_seat_id && new_seat_id.present? ? 'moved' : new_status } }
        format.html do
          flash[:notice] = message
          redirect_to @ticket
        end
      end
    else
      Rails.logger.error "Update failed: #{@ticket.errors.full_messages.join(', ')}"
      
      respond_to do |format|
        format.json { render json: { success: false, errors: @ticket.errors.full_messages }, status: :unprocessable_entity }
        format.html do
          flash[:alert] = "Failed to update ticket: #{@ticket.errors.full_messages.join(', ')}"
          redirect_to edit_ticket_path(@ticket)
        end
      end
    end
  end

  # DELETE /tickets/:id
  def destroy
    showtime_id = @ticket.showtime_id
    @ticket.destroy
    flash[:notice] = "Ticket deleted successfully"
    redirect_to new_ticket_path(showtime_id: showtime_id)
  end

  private

  def set_ticket
    @ticket = Ticket.find(params[:id])
  end

  def tickets_params
    params.require(:ticket).permit(:showtime_id, seat_ids: [])
  end

  def ticket_update_params
    params.require(:ticket).permit(:seat_id, :status)
  end

  def require_active_workday
    unless current_workday
      flash[:alert] = "No active shift. Please start your shift first."
      redirect_to root_path
    end
  end
end
