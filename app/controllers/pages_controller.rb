class PagesController < ApplicationController
  def home
    @latest_run = ForecastRun.order(created_at: :desc).first
    if @latest_run
      @forecasts_preview = @latest_run.forecasts.includes(:hall).where('showtime_at >= ?', Time.current).order(:showtime_at).limit(12)
    else
      @forecasts_preview = []
    end
  end
end
