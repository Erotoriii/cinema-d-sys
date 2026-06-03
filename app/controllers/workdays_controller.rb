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

    if @workday.save
      redirect_to root_path, notice: "Shift started at #{cinema.name}."
    else
      redirect_to root_path, alert: "Failed to start shift."
    end
  end

  # PATCH/PUT /workdays/:id - End a shift        
  def update
    @workday = current_user.workdays.find(params[:id])

    # 1. Знаходимо всі продані квитки за цю зміну
    sold_tickets = Ticket.where(workday_id: @workday.id, status: 'Sold')
    
    # 2. ДИНАМІЧНИЙ ПІДРАХУНОК: об'єднуємо з сеансами та сумуємо їхні реальні ціни
    total_revenue = sold_tickets.joins(:showtime).sum('showtimes.price')

    ActiveRecord::Base.transaction do
      @workday.update!(end_time: Time.current)

      Report.create!(
        workday_id: @workday.id,
        total_sales: total_revenue,
        status: 'pending'
      )
    end

    redirect_to root_path, notice: "Робочу зміну завершено. Автозвіт сформовано успішно! Загальна виручка: #{total_revenue} грн."
  end

  private

  def workday_params
    params.require(:workday).permit(:cinema_id)
  end
end
