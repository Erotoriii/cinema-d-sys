class ForecastsController < ApplicationController
  before_action :authenticate_user!

  def index
    @runs = ForecastRun.order(created_at: :desc).limit(20)
  end

  def show
    @run = ForecastRun.find(params[:id])
    @forecasts = @run.forecasts.includes(:hall).order(:showtime_at)
  end
end
