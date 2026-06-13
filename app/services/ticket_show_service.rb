class TicketShowService
  def initialize(showtime_id)
    @showtime_id = showtime_id
  end

  def load_data
    @showtime = Showtime.includes(:movie, hall: :seats).find(@showtime_id)
    @hall = @showtime.hall
    @seats = @hall.seats.order(:row, :number)
    @sold_seat_ids = Ticket.where(showtime_id: @showtime.id).where(status: ['sold', 'pending']).pluck(:seat_id)
    @movie = @showtime.movie
    @tickets_by_seat = Ticket.where(showtime_id: @showtime.id).index_by(&:seat_id)
    @latest_forecast = load_latest_forecast
    
    {
      showtime: @showtime,
      hall: @hall,
      seats: @seats,
      sold_seat_ids: @sold_seat_ids,
      movie: @movie,
      tickets_by_seat: @tickets_by_seat,
      latest_forecast: @latest_forecast,
      forecast_data: build_forecast_data(@latest_forecast)
    }
  end

  private

  def load_latest_forecast
    Forecast
      .includes(:forecast_run)
      .where(showtime_id: @showtime_id)
      .order('forecast_runs.run_at DESC')
      .first
  end

  def build_forecast_data(forecast)
    return {} unless forecast.present?

    {
      predicted_occupancy_pct: forecast.predicted_fill_pct.to_f,
      predicted_tickets_count: forecast.predicted_tickets.to_f.round,
      forecast_generated_at: forecast.forecast_run&.run_at
    }
  end
end
