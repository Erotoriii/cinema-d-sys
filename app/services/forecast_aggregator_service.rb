class ForecastAggregatorService
  def initialize(forecasts)
    @forecasts = forecasts
  end

  def aggregate
    {
      forecasts_by_date: group_by_date,
      forecasts_by_movie: group_by_movie,
      total_predicted_tickets: calculate_total_tickets,
      expected_revenue: calculate_expected_revenue,
      average_occupancy: calculate_average_occupancy,
      low_risk_sessions: low_risk_sessions,
      high_opportunity_sessions: high_opportunity_sessions,
      top_movies_by_tickets: top_movies_by_tickets
    }
  end

  private

  attr_reader :forecasts

  def group_by_date
    forecasts.group_by { |forecast| forecast.showtime_at.to_date }
  end

  def group_by_movie
    forecasts.group_by do |forecast|
      forecast.showtime&.movie&.title || "Без назви"
    end
  end

  def calculate_total_tickets
    forecasts.sum { |f| f.predicted_tickets.to_f }
  end

  def calculate_expected_revenue
    forecasts.sum { |f| f.predicted_tickets.to_f * (f.showtime&.price.to_f || 0.0) }
  end

  def calculate_average_occupancy
    fills = forecasts.map { |f| f.predicted_fill_pct }.compact
    fills.any? ? (fills.sum / fills.size) : 0.0
  end

  def low_risk_sessions
    forecasts
      .select { |f| f.predicted_fill_pct && f.predicted_fill_pct < 30 }
      .sort_by(&:predicted_fill_pct)
  end

  def high_opportunity_sessions
    forecasts
      .select { |f| f.predicted_fill_pct && f.predicted_fill_pct > 70 }
      .sort_by { |f| -f.predicted_fill_pct }
  end

  def top_movies_by_tickets
    movie_totals = forecasts.each_with_object(Hash.new(0.0)) do |f, totals|
      title = f.showtime&.movie&.title || "Без назви"
      totals[title] += f.predicted_tickets.to_f
    end
    movie_totals.sort_by { |_k, v| -v }.first(5)
  end
end
