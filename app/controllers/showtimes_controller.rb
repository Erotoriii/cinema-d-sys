class ShowtimesController < ApplicationController
  before_action :set_showtime, only: [:show, :edit, :update, :destroy]
  before_action :authorize_manager!, except: [:index, :show]

  # GET /showtimes
  def index
    @showtimes = Showtime.includes(:movie, :hall).order(:start_time)
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
    redirect_to showtimes_url, alert: "Not authorized." unless current_user&.manager?
  end
end
