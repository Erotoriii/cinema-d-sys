class PagesController < ApplicationController
  def home
    @latest_run = ForecastRun.order(created_at: :desc).first
    if @latest_run
      preview_scope = @latest_run.forecasts.includes(:hall).where('showtime_at >= ?', Time.current)
      if current_workday.present?
        preview_scope = preview_scope.joins(:hall).where(halls: { cinema_id: current_workday.cinema_id })
      end

      @forecasts_preview = preview_scope.order(:showtime_at).limit(12)
    else
      @forecasts_preview = []
    end
  end
end
