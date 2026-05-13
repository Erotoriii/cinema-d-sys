class CinemasController < ApplicationController
  before_action :set_cinema, only: [:show, :edit, :update, :destroy]

  # GET /cinemas
  def index
    @cinemas = Cinema.all
  end

  # GET /cinemas/:id
  def show
  end

  # GET /cinemas/new
  def new
    @cinema = Cinema.new
  end

  # POST /cinemas
  def create
    @cinema = Cinema.new(cinema_params)
    if @cinema.save
      redirect_to @cinema, notice: "Cinema was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # GET /cinemas/:id/edit
  def edit
  end

  # PATCH/PUT /cinemas/:id
  def update
    if @cinema.update(cinema_params)
      redirect_to @cinema, notice: "Cinema was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /cinemas/:id
  def destroy
    @cinema.destroy
    redirect_to cinemas_url, notice: "Cinema was successfully deleted."
  end

  private

  def set_cinema
    @cinema = Cinema.find(params[:id])
  end

  def cinema_params
    params.require(:cinema).permit(:name, :address, :company_id)
  end
end
