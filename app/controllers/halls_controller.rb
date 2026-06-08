class HallsController < ApplicationController
  before_action :set_hall, only: [:show, :edit, :update, :destroy]
  before_action :set_available_cinemas, only: [:index, :new, :create, :edit, :update]
  before_action :authorize_manager!
  # GET /halls
  def index
    @halls = Hall.where(cinema_id: allowed_cinema_ids)
  end
# Fetch all halls where cinema_id is in current_user.company.cinema_ids
  # GET /halls/:id
  def show
  end

  # GET /halls/new
  def new
    @hall = Hall.new
  end

  # POST /halls
  def create
    @hall = Hall.new(hall_params)

    unless allowed_cinema_ids.include?(@hall.cinema_id)
      @hall.errors.add(:cinema_id, "is not available for the active cinema scope")
      render :new, status: :unprocessable_entity
      return
    end

    if @hall.save
      redirect_to @hall, notice: "Hall was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # GET /halls/:id/edit
  def edit
  end

  # PATCH/PUT /halls/:id
  def update
    if @hall.update(hall_params)
      redirect_to @hall, notice: "Hall was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /halls/:id
  def destroy
    @hall.destroy
    redirect_to halls_url, notice: "Hall was successfully deleted."
  end

  private

  def set_hall
    @hall = Hall.where(cinema_id: allowed_cinema_ids).find(params[:id])
  end

  def hall_params
    params.require(:hall).permit(:name, :cinema_id, :rows, :seats_per_row)
  end

  def allowed_cinema_ids
    return [] if current_user.company.nil?
    return [current_workday.cinema_id] if current_workday.present?

    current_user.company.cinema_ids
  end

  def set_available_cinemas
    @available_cinemas = Cinema.where(id: allowed_cinema_ids)
  end
end
