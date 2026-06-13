class ForecastAccuracyJob < ApplicationJob
  queue_as :default

  def perform(forecast_run_id: nil, days_back: 7)
    @forecast_run = ForecastRun.find(forecast_run_id) if forecast_run_id.present?
    
    days_back    = days_back.to_i
    cutoff_start = (Time.current - days_back.days).beginning_of_day
    cutoff_end   = Time.current

    Rails.logger.info("=== FORECAST ACCURACY REPORT: #{days_back} days (#{cutoff_start.to_date} to #{cutoff_end.to_date}) ===")

    completed_forecasts = Forecast
      .joins(:showtime)
      .where('showtimes.start_time >= ? AND showtimes.start_time <= ?', cutoff_start, cutoff_end)
      .where('showtimes.start_time < ?', Time.current - 1.hour)
      .includes(:hall, :showtime)

    if completed_forecasts.empty?
      Rails.logger.info("FORECAST ACCURACY: No completed forecasts found in period.")
      return
    end

    # Збираємо актуальну кількість квитків одним запитом — без N+1
    showtime_ids  = completed_forecasts.map(&:showtime_id).uniq
    ticket_counts = Ticket
      .where(showtime_id: showtime_ids, status: %w[sold pending])
      .group(:showtime_id)
      .count

    all_errors = []

    completed_forecasts.group_by(&:hall_id).each do |hall_id, hall_forecasts|
      hall             = hall_forecasts.first.hall
      hall_errors      = []
      segment_errors   = { weekday_day: [], weekday_night: [], weekend: [] }

      hall_forecasts.each do |forecast|
        actual_tickets    = ticket_counts[forecast.showtime_id].to_i
        predicted_tickets = forecast.predicted_tickets.to_i

        next if actual_tickets.zero? && predicted_tickets.zero?

        error_pct = if actual_tickets.zero?
          100.0
        else
          ((actual_tickets - predicted_tickets).abs.to_f / actual_tickets) * 100.0
        end

        hall_errors << error_pct
        all_errors  << error_pct

        # Класифікуємо сегмент для деталізації
        hour    = forecast.showtime.start_time.hour
        is_wknd = forecast.showtime.start_time.saturday? || forecast.showtime.start_time.sunday?
        segment = classify_segment(hour, is_wknd)
        segment_errors[segment] << error_pct
      end

      if hall_errors.empty?
        Rails.logger.info("FORECAST ACCURACY Hall #{hall.id} (#{hall.name}): No valid forecasts.")
        next
      end

      mape = mape_for(hall_errors)
      Rails.logger.info("FORECAST ACCURACY Hall #{hall.id} (#{hall.name}): MAPE=#{mape}% (n=#{hall_errors.length})")

      # Деталізація по сегментах
      segment_errors.each do |segment, errors|
        next if errors.empty?
        seg_mape = mape_for(errors)
        Rails.logger.info("  └─ #{segment}: MAPE=#{seg_mape}% (n=#{errors.length})")
      end
    end

    # Глобальний MAPE по всіх залах
    unless all_errors.empty?
      global_mape = mape_for(all_errors)
      Rails.logger.info("FORECAST ACCURACY GLOBAL: MAPE=#{global_mape}% (n=#{all_errors.length} total)")
      
      # Зберігаємо MAPE до ForecastRun якщо він був передданий
      if @forecast_run.present?
        @forecast_run.update(global_mape: global_mape)
        Rails.logger.info("FORECAST ACCURACY: MAPE=#{global_mape}% saved to ForecastRun #{@forecast_run.id}")
      end
    end

    Rails.logger.info("=== END FORECAST ACCURACY REPORT ===")
  end

  private

  def classify_segment(hour, is_weekend)
    return :weekend      if is_weekend
    return :weekday_day  if hour < 18
    :weekday_night
  end

  def mape_for(errors)
    return 0.0 if errors.empty?
    (errors.sum / errors.length).round(2)
  end
end