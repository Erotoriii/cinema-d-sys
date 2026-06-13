class ForecastsController < ApplicationController
  before_action :authenticate_user!

  def index
    @runs = ForecastRun.order(created_at: :desc).limit(20)
    @latest_run = @runs.first

    if @latest_run
      @latest_forecasts = scoped_forecasts(@latest_run.forecasts)
                           .includes(hall: :cinema, showtime: { movie: [] })
                           .order(:showtime_at)
                           .to_a
      
      # Use service to aggregate forecasts data
      aggregated_data = ForecastAggregatorService.new(@latest_forecasts).aggregate
      @forecasts_by_date = aggregated_data[:forecasts_by_date]
      @forecasts_by_movie = aggregated_data[:forecasts_by_movie]
      @total_predicted_tickets = aggregated_data[:total_predicted_tickets]
      @expected_revenue = aggregated_data[:expected_revenue]
      @average_occupancy = aggregated_data[:average_occupancy]
      @low_risk_sessions = aggregated_data[:low_risk_sessions]
      @high_opportunity_sessions = aggregated_data[:high_opportunity_sessions]
      @top_movies_by_tickets = aggregated_data[:top_movies_by_tickets]
      @global_mape = @latest_run.global_mape
    else
      initialize_empty_forecast_data
    end
  end

  def show
    @run = ForecastRun.find(params[:id])
    @forecasts = scoped_forecasts(@run.forecasts)
                 .includes(hall: :cinema, showtime: { movie: [] })
                 .order(:showtime_at)
    @global_mape = @run.global_mape
  end

  def run
    ForecastRunnerJob.perform_later(horizon_days: 7)
    flash[:notice] = "Прогнозування запущено у фоновому режимі. Будь ласка, зачекайте кілька хвилин та оновіть сторінку."
    redirect_to forecasts_path
  end

  private

  def initialize_empty_forecast_data
    @latest_forecasts = []
    @forecasts_by_date = {}
    @forecasts_by_movie = {}
    @total_predicted_tickets = 0.0
    @expected_revenue = 0.0
    @average_occupancy = 0.0
    @low_risk_sessions = []
    @high_opportunity_sessions = []
    @top_movies_by_tickets = []
    @global_mape = nil
  end

  def scoped_forecasts(relation)
    return relation unless current_workday.present?

    relation.joins(:hall).where(halls: { cinema_id: current_workday.cinema_id })
  end
end
