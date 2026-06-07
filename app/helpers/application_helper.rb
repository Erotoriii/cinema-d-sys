module ApplicationHelper
	def forecast_showtime_for(forecast)
		return nil unless forecast&.hall_id && forecast.showtime_at

		@forecast_showtime_cache ||= {}
		@forecast_showtime_cache[[forecast.id, forecast.hall_id, forecast.showtime_at.to_i]] ||= begin
			Showtime.includes(:movie).find_by(hall_id: forecast.hall_id, start_time: forecast.showtime_at)
		end
	end

	def forecast_movie_title(forecast)
		return forecast.movie.title if forecast.respond_to?(:movie) && forecast.movie.present?
		forecast_showtime_for(forecast)&.movie&.title.presence || "Синтетичний слот"
	end

	def forecast_occupancy_pct(forecast)
		forecast.predicted_fill_pct.to_f
	end

	def forecast_occupancy_color(percentage)
		return '#16a34a' if percentage < 25
		return '#f59e0b' if percentage < 50

		'#ef4444'
	end

	def forecast_occupancy_label(percentage)
		return 'Низька завантаженість' if percentage < 25
		return 'Помірна завантаженість' if percentage < 50

		'Висока завантаженість'
	end

	private
end
