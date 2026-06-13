class ShowtimesController < ApplicationController
  before_action :set_showtime, only: [:show, :edit, :update, :destroy]
  before_action :load_form_collections, only: [:new, :create]
  before_action :authorize_manager!, except: [:index, :show]

  # GET /showtimes
  def index
    base_scope = scoped_showtimes

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

    unless allowed_hall_ids.include?(@showtime.hall_id)
      @showtime.errors.add(:hall_id, "is not available for the selected cinema scope")
      render :new, status: :unprocessable_entity
      return
    end

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
    unless allowed_hall_ids.include?(showtime_params[:hall_id].to_i)
      @showtime.errors.add(:hall_id, "is not available for the selected cinema scope")
      render :edit, status: :unprocessable_entity
      return
    end

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
    @showtime = scoped_showtimes.find(params[:id])
  end

  def showtime_params
    params.require(:showtime).permit(:movie_id, :hall_id, :start_time, :price)
  end

  def batch_showtime_params
    params.require(:batch_showtime).permit(:movie_id, :hall_id, :start_date, :end_date, :schedule_text, :base_price)
  end

  def load_form_collections
    @movies = Movie.where(deleted_at: nil, company_id: current_user.company_id).order(:title)
    @halls = Hall.where(cinema_id: allowed_cinema_ids).order(:name)
  end

  def scoped_showtimes
    if current_workday.present?
      return Showtime.joins(:hall).where(halls: { cinema_id: current_workday.cinema_id })
    end

    if current_user.admin_or_manager?
      return Showtime.joins(:hall).where(halls: { cinema_id: allowed_cinema_ids })
    end

    flash.now[:alert] = "Please start a shift first to view showtimes."
    Showtime.none
  end

  def allowed_cinema_ids
    @allowed_cinema_ids ||= begin
      return [] if current_user.company.nil?
      return [current_workday.cinema_id] if current_workday.present?
      current_user.company.cinema_ids
    end
  end

  def allowed_hall_ids
    @allowed_hall_ids ||= Hall.where(cinema_id: allowed_cinema_ids).pluck(:id)
  end

  def authorize_manager!
    redirect_to showtimes_url, alert: "Not authorized." unless current_user&.admin_or_manager?
  end
end
