class WorkdaysController < ApplicationController
  before_action :authenticate_user!

  # POST /workdays - Start a shift
  def create
    cinema = available_cinemas.find(workday_params[:cinema_id])

    active_workday = current_user.workdays.where(end_time: nil).order(:start_time).last

    if active_workday.present?
      if active_workday.cinema_id == cinema.id
        redirect_to root_path, notice: "Shift is already active at #{cinema.name}."
        return
      end

      active_workday.close_shift!
    end

    @workday = current_user.workdays.build(
      cinema: cinema,
      start_time: Time.current,
      end_time: nil
    )
    @workday.capture_product_snapshot!

    if @workday.save
      # store active workday in session for quick lookup
      session[:workday_id] = @workday.id
      respond_to do |format|
        format.html { redirect_to root_path, notice: "Shift started at #{cinema.name}." }
        format.json { render json: { success: true, workday_id: @workday.id }, status: :created }
      end
    else
      respond_to do |format|
        format.html { redirect_to root_path, alert: "Failed to start shift." }
        format.json { render json: { success: false, errors: @workday.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_to root_path, alert: "Selected cinema is not available for your account." }
      format.json { render json: { success: false, errors: ["Selected cinema is not available for your account."] }, status: :unprocessable_entity }
    end
  end

  # PATCH/PUT /workdays/:id - End a shift        
  def update
    @workday = current_user.workdays.find(params[:id])
    report = @workday.close_shift!
    session[:workday_id] = nil

    redirect_to root_path, notice: "Робочу зміну завершено. Виручка з квитків: #{report.total_revenue} грн, бар: #{report.total_sales} грн."
  end

  # PATCH /workdays/:id/close - Close shift and generate report
  def close
    @workday = Workday.find(params[:id])
    report = @workday.close_shift!
    
    #очищаємо сесію, щоб сайт зрозумів, що зміна завершилась
    session[:workday_id] = nil 
    
    redirect_to root_path, notice: "Shift closed successfully. Ticket revenue: #{report.total_revenue} грн, bar revenue: #{report.total_sales} грн."
  end

  private

  def workday_params
    params.require(:workday).permit(:cinema_id)
  end

  def available_cinemas
    company_id = current_user.company_id
    return Cinema.none if company_id.blank?

    Cinema.where(company_id: company_id)
  end
end
