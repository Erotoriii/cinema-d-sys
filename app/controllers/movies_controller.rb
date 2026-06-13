class MoviesController < ApplicationController
  before_action :set_movie, only: [:show, :edit, :update, :destroy]
  before_action :authorize_manager!
  # GET /movies
  def index
    @movies = Movie.where(company_id: current_user.company_id, deleted_at: nil).order(:title)
  end

  # GET /movies/:id
  def show
  end

  # GET /movies/new
  def new
    @movie = Movie.new
  end

  # POST /movies
  # 1. Initialize movie with movie_params.
  # 2. Assign current_user's company_id to the new movie.
  # 3. Save the movie. If successful, redirect to @movie with a notice. Else, render :new.      
  def create
    @movie = Movie.new(movie_params)
    @movie.company_id = current_user.company_id  # Ensure the new movie is associated with the current user's company
    if @movie.save
      redirect_to @movie, notice: "Movie was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # GET /movies/:id/edit
  def edit
  end

  # PATCH/PUT /movies/:id
  def update
    if @movie.update(movie_params)
      redirect_to @movie, notice: "Movie was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /movies/:id
  def destroy
    @movie.update(deleted_at: Time.current)
    redirect_to movies_url, notice: "Movie was successfully deleted."
  end

  private

  def set_movie
    @movie = Movie.where(company_id: current_user.company_id, deleted_at: nil).find(params[:id])
  end

  def movie_params
    params.require(:movie).permit(:title, :duration, :description)
  end
end
