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
    @workday = current_workday

    if @workday.nil?
      redirect_to root_path, alert: "No active shift found."
      return
    end

    if @workday.update(end_time: Time.current)
      redirect_to root_path, notice: "Shift ended. Thank you for your work!"
    else
      redirect_to root_path, alert: "Failed to end shift."
    end
  end

  private

  def workday_params
    params.require(:workday).permit(:cinema_id)
  end
end
