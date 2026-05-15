class HallsController < ApplicationController
  before_action :set_hall, only: [:show, :edit, :update, :destroy]
  before_action :authorize_manager!
  # GET /halls
  def index
    @halls = Hall.all
  end

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
    @hall = Hall.find(params[:id])
  end

  def hall_params
    params.require(:hall).permit(:name, :cinema_id, :rows, :seats_per_row)
  end
end
