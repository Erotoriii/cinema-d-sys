class ShowtimesController < ApplicationController
  before_action :set_showtime, only: [:show, :edit, :update, :destroy]
  before_action :authorize_manager!, except: [:index, :show]

  # GET /showtimes
  def index
    if current_workday
      # If user has an active shift, show only showtimes from that cinema
      @showtimes = Showtime.joins(:hall).where(halls: { cinema_id: current_workday.cinema_id })
                           .includes(:movie, :hall).order(:start_time)
    elsif current_user.admin_or_manager?
      # Admins and managers can see all showtimes
      @showtimes = Showtime.includes(:movie, :hall).order(:start_time)
    else
      # Staff without active shift cannot view showtimes
      @showtimes = []
      flash.now[:alert] = "Please start a shift first to view showtimes."
    end
  end

  # GET /showtimes/:id
  def show
  end

  # GET /showtimes/new
  def new
    @showtime = Showtime.new
  end

  # POST /showtimes
  def create
    @showtime = Showtime.new(showtime_params)
    if @showtime.save
      redirect_to @showtime, notice: "Showtime was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # GET /showtimes/:id/edit
  def edit
  end

  # PATCH/PUT /showtimes/:id
  def update
    if @showtime.update(showtime_params)
      redirect_to @showtime, notice: "Showtime was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /showtimes/:id
  def destroy
    @showtime.destroy
    redirect_to showtimes_url, notice: "Showtime was successfully deleted."
  end

  private

  def set_showtime
    @showtime = Showtime.find(params[:id])
  end

  def showtime_params
    params.require(:showtime).permit(:movie_id, :hall_id, :start_time)
  end

  def authorize_manager!
    redirect_to showtimes_url, alert: "Not authorized." unless current_user&.admin_or_manager?
  end
end
