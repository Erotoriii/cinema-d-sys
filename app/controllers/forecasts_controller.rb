class ForecastsController < ApplicationController
  before_action :authenticate_user!

  def index
    @runs = ForecastRun.order(created_at: :desc).limit(20)
    @latest_run = @runs.first

    if @latest_run
      @latest_forecasts = @latest_run.forecasts.includes(:hall, :movie, showtime: :movie).order(:showtime_at).to_a
      @forecasts_by_date = @latest_forecasts.group_by { |forecast| forecast.showtime_at.to_date }
      @forecasts_by_movie = @latest_forecasts.group_by { |forecast| forecast.movie&.title || forecast.showtime&.movie&.title || "Без назви" }

      @total_predicted_tickets = @latest_forecasts.sum { |f| f.predicted_tickets.to_f }
      @expected_revenue = @latest_forecasts.sum { |f| f.predicted_tickets.to_f * (f.showtime&.price.to_f || 0.0) }

      fills = @latest_forecasts.map { |f| f.predicted_fill_pct }.compact
      @average_occupancy = fills.any? ? (fills.sum / fills.size) : 0.0

      @low_risk_sessions = @latest_forecasts.select { |f| f.predicted_fill_pct && f.predicted_fill_pct < 30 }.sort_by(&:predicted_fill_pct)
      @high_opportunity_sessions = @latest_forecasts.select { |f| f.predicted_fill_pct && f.predicted_fill_pct > 70 }.sort_by { |f| -f.predicted_fill_pct }

      movie_totals = Hash.new(0.0)
      @latest_forecasts.each do |f|
        title = f.movie&.title || f.showtime&.movie&.title || "Без назви"
        movie_totals[title] += f.predicted_tickets.to_f
      end
      @top_movies_by_tickets = movie_totals.sort_by { |_k, v| -v }.first(5)
    else
      @latest_forecasts = []
      @forecasts_by_date = {}
      @forecasts_by_movie = {}
      @total_predicted_tickets = 0.0
      @expected_revenue = 0.0
      @average_occupancy = 0.0
      @low_risk_sessions = []
      @high_opportunity_sessions = []
      @top_movies_by_tickets = []
    end
  end

  def show
    @run = ForecastRun.find(params[:id])
    @forecasts = @run.forecasts.includes(:hall, :movie, showtime: :movie).order(:showtime_at)
  end

  def run
    ForecastRunnerJob.perform_later(horizon_days: 7)
    flash[:notice] = "Прогнозування запущено у фоновому режимі. Будь ласка, зачекайте кілька хвилин та оновіть сторінку."
    redirect_to forecasts_path
  end
end
