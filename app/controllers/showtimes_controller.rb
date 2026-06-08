class ShowtimesController < ApplicationController
  before_action :set_showtime, only: [:show, :edit, :update, :destroy]
  before_action :load_form_collections, only: [:new, :create]
  before_action :authorize_manager!, except: [:index, :show]

  # GET /showtimes
  def index
    base_scope = if current_workday
      # If user has an active shift, show only showtimes from that cinema
      Showtime.joins(:hall).where(halls: { cinema_id: current_workday.cinema_id })
    elsif current_user.admin_or_manager?
      cinema_ids = current_user.company&.cinema_ids || []
      # Admins and managers can see all showtimes ONLY FOR THEIR COMPANY
      Showtime.joins(:hall).where(halls: { cinema_id: cinema_ids })
    else
      # Staff without active shift cannot view showtimes
      Showtime.none
      flash.now[:alert] = "Please start a shift first to view showtimes."
    end

    day_boundary = Time.zone.today.beginning_of_day
    @showing_past_showtimes = current_user&.admin? && params[:past].present?

    @showtimes = if @showing_past_showtimes
      base_scope.where("showtimes.start_time < ?", day_boundary)
                .includes(:movie, hall: :cinema)
                .order(start_time: :desc)
    else
      base_scope.where("showtimes.start_time >= ?", day_boundary)
                .includes(:movie, hall: :cinema)
                .order(:start_time)
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

  # POST /showtimes/create_batch
  def create_batch
    result = BatchShowtimeCreator.new(
      movie_id: batch_showtime_params[:movie_id],
      hall_id: batch_showtime_params[:hall_id],
      start_date: batch_showtime_params[:start_date],
      end_date: batch_showtime_params[:end_date],
      schedule_text: batch_showtime_params[:schedule_text],
      base_price: batch_showtime_params[:base_price]
    ).call

    redirect_to showtimes_path, notice: "Створено #{result[:created_count]} сеанс(ів)."
  rescue StandardError => e
    redirect_to showtimes_path, alert: e.message
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
    params.require(:showtime).permit(:movie_id, :hall_id, :start_time, :price)
  end

  def batch_showtime_params
    params.require(:batch_showtime).permit(:movie_id, :hall_id, :start_date, :end_date, :schedule_text, :base_price)
  end

  def load_form_collections
    @movies = Movie.where(deleted_at: nil, company_id: current_user.company_id).order(:title)
    @halls = Hall.where(cinema_id: current_user.company&.cinema_ids).order(:name)
  end

  def authorize_manager!
    redirect_to showtimes_url, alert: "Not authorized." unless current_user&.admin_or_manager?
  end
end
