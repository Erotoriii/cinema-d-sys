class TicketsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_ticket, only: [:show, :edit]
  before_action :require_active_workday_or_admin, only: [:create, :update, :destroy]

  def new
    service_data = TicketShowService.new(params[:showtime_id]).load_data
    
    @showtime = service_data[:showtime]
    @hall = service_data[:hall]
    @seats = service_data[:seats]
    @sold_seat_ids = service_data[:sold_seat_ids]
    @movie = service_data[:movie]
    @tickets_by_seat = service_data[:tickets_by_seat]
    @latest_forecast_for_showtime = service_data[:latest_forecast]
    
    forecast_data = service_data[:forecast_data]
    @predicted_occupancy_pct = forecast_data[:predicted_occupancy_pct]
    @predicted_tickets_count = forecast_data[:predicted_tickets_count]
    @forecast_generated_at = forecast_data[:forecast_generated_at]
  end

  # POST /tickets
  def create
    showtime_id = tickets_params[:showtime_id]
    seat_ids = tickets_params[:seat_ids] || []
    generate_pdf = boolean_param?(tickets_params[:generate_pdf])

    if showtime_id.blank?
      redirect_to root_path
      return
    end

    if seat_ids.empty?
      flash[:alert] = "Please select at least one seat."
      redirect_to new_ticket_path(showtime_id: showtime_id)
      return
    end

    showtime = Showtime.find(showtime_id)

    result = TicketCreatorService.new(
      showtime: showtime,
      seat_ids: seat_ids,
      workday: current_workday,
      current_user: current_user
    ).call

    handle_ticket_creation_result(result, showtime, generate_pdf)
  rescue TicketCreatorService::PermissionDenied => e
    flash[:alert] = e.message
    redirect_to new_ticket_path(showtime_id: showtime_id)
  end

  def show
  end

  def edit
    hall = @ticket.showtime.hall
    sold_seat_ids = @ticket.showtime.tickets.where.not(id: @ticket.id).pluck(:seat_id)
    @available_seats = hall.seats.where.not(id: sold_seat_ids).order(:row, :number)
    
    render layout: false if request.xhr?
  end

  # PATCH/PUT /tickets/:id
  def update
    @ticket = Ticket.find(params[:id])
    
    Rails.logger.debug "=== TICKET UPDATE DEBUG ==="
    Rails.logger.debug "params: #{params.inspect}"
    Rails.logger.debug "ticket_update_params: #{ticket_update_params.inspect}"

    service = TicketUpdateService.new(@ticket, ticket_update_params)
    result = service.update!

    if result[:success]
      Rails.logger.debug "Update successful: #{result[:message]}"
      
      respond_to do |format|
        format.json { render json: { success: true, message: result[:message], new_status: result[:new_status] } }
        format.html do
          flash[:notice] = result[:message]
          redirect_to @ticket
        end
      end
    else
      Rails.logger.error "Update failed: #{result[:errors].join(', ')}"
      
      respond_to do |format|
        format.json { render json: { success: false, errors: result[:errors] }, status: :unprocessable_entity }
        format.html do
          flash[:alert] = "Failed to update ticket: #{result[:errors].join(', ')}"
          redirect_to edit_ticket_path(@ticket)
        end
      end
    end
  end

  # DELETE /tickets/:id
  def destroy
    @ticket = Ticket.find(params[:id])
    showtime_id = @ticket.showtime_id
    @ticket.destroy
    flash[:notice] = "Ticket deleted successfully"
    redirect_to new_ticket_path(showtime_id: showtime_id)
  end

  # Callback methods (must be public, before private)
  def set_ticket
    @ticket = Ticket.find(params[:id])
  end

  def require_active_workday_or_admin
    unless current_workday || current_user.admin_or_manager?
      flash[:alert] = "No active shift. Please start your shift first."
      redirect_to root_path
    end
  end

  private

  def handle_ticket_creation_result(result, showtime, generate_pdf)
    created_count = result[:created_count]
    errors = result[:errors]
    sold_tickets = result[:sold_tickets]


    if created_count > 0
      notice = "#{created_count} ticket(s) sold successfully"
      notice += " (Errors: #{errors.join(', ')})" if errors.any?
      flash[:notice] = notice
    elsif errors.any?
      flash[:alert] = "No tickets sold. #{errors.join(', ')}"
    else
      flash[:alert] = "No seats selected."
    end

    if generate_pdf && sold_tickets.any?
      handle_pdf_generation(showtime, sold_tickets)
    else
      redirect_to new_ticket_path(showtime_id: showtime.id)
    end
  end

  def handle_pdf_generation(showtime, sold_tickets)
    showtime = Showtime.includes(:movie, :hall).find(showtime.id)
    begin
      pdf_data = TicketPdfGenerator.new(showtime: showtime, tickets: sold_tickets).render
      send_data(
        pdf_data,
        filename: pdf_filename_for(showtime),
        type: "application/pdf",
        disposition: "attachment"
      )
    rescue TicketPdfGenerator::MissingDependencyError => e
      flash[:alert] = "Квитки продано, але PDF тимчасово недоступний на цьому сервері."
      redirect_to new_ticket_path(showtime_id: showtime.id)
    end
  end

  def tickets_params
    params.require(:ticket).permit(:showtime_id, :generate_pdf, seat_ids: [])
  end

  def ticket_update_params
    params.require(:ticket).permit(:seat_id, :status)
  end

  def boolean_param?(value)
    ActiveModel::Type::Boolean.new.cast(value)
  end

  def pdf_filename_for(showtime)
    "tickets_showtime_#{showtime.id}_#{Time.current.strftime('%Y%m%d_%H%M%S')}.pdf"
  end
end
