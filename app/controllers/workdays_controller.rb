class WorkdaysController < ApplicationController
  before_action :authenticate_user!

  # POST /workdays - Start a shift
  def create
    cinema_id = workday_params[:cinema_id]
    cinema = Cinema.find(cinema_id)

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
end
