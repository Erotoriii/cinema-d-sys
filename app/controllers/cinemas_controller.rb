class CinemasController < ApplicationController
  before_action :set_cinema, only: [:show, :edit, :update, :destroy]
  before_action :authorize_admin!
  # GET /cinemas
  # Fetch all cinemas where company_id matches current_user.company_id (with caching)
  def index
    @cinemas = Cinema.where(company_id: current_user.company_id).order(:name)
  end

  # GET /cinemas/:id
  def show
  end

  # GET /cinemas/new
  def new
    @cinema = Cinema.new
  end

  # Assign current_user's company_id to this record before saving       
  # POST /cinemas
  def create
    @cinema = Cinema.new(cinema_params)
    @cinema.company_id = current_user.company_id
    if @cinema.save
      redirect_to @cinema, notice: 'Кінотеатр успішно створено.'
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
    params.require(:cinema).permit(:name, :address)
  end
end
