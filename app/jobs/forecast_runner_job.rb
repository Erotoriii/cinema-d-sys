class ForecastRunnerJob < ApplicationJob
  queue_as :default

  def perform(horizon_days: 7)
    # For each hall, gather historical data and train a regression with Ridge regularization, then predict next showtimes
    run = ForecastRun.create!(run_at: Time.current, horizon_days: horizon_days, model: 'regression')

    Hall.find_each do |hall|
      rows = gather_training_rows_for(hall)
      trainer = Forecasting::RegressionTrainer.new(rows)
      ridge_lambda = 1.0
      coefs = trainer.train(ridge: ridge_lambda)

      upcoming = upcoming_showtimes_for(hall, horizon_days)
      # If there are no actual scheduled showtimes in the horizon, but we have historical rows,
      # synthesize upcoming times using historical hours for the next `horizon_days` days.
      if upcoming.empty? && rows.any?
        hours = rows.map { |r| r[:hour] }.uniq
        synthetic = []
        (0...horizon_days).each do |d|
          base = Time.current.beginning_of_day + d.days
          hours.each do |h|
            synthetic << (base + h.to_i.hours)
          end
        end
        upcoming = synthetic.uniq.sort
      end
      if coefs.present?
        upcoming.each do |showtime_at|
          features = build_features(hall, showtime_at)
          predicted = trainer.predict(coefs, features)

          Forecast.create!(
            forecast_run: run,
            hall: hall,
            showtime_at: showtime_at,
            predicted_tickets: predicted.round(2)
          )
        end
      else
        # fallback: moving average by same weekday & hour from historical rows
        if rows.any? && upcoming.any?
          # build index by [dow,hour]
          index = {}
          rows.each do |r|
            dow = r[:dow]
            hour = r[:hour]
            index[[dow, hour]] ||= []
            index[[dow, hour]] << r[:sold].to_f
          end

          upcoming.each do |showtime_at|
            key = [showtime_at.wday, showtime_at.hour]
            vals = index[key] || []
            predicted = vals.any? ? (vals.sum / vals.size) : 0.0
            Forecast.create!(forecast_run: run, hall: hall, showtime_at: showtime_at, predicted_tickets: predicted.round(2))
          end
        end
      end
    end
  end

  private

  def gather_training_rows_for(hall)
    # collect historical sold tickets by showtime
    # collect historical sold tickets by showtime, include movie_id
    rows = Ticket.joins(:showtime).where(showtimes: { hall_id: hall.id }).where(status: %w[sold Sold]).group('showtimes.id, showtimes.start_time, showtimes.movie_id').pluck('showtimes.id, showtimes.start_time, showtimes.movie_id, count(tickets.id) as sold_count')

    # compute movie popularity as average sold per show for that movie
    movie_ids = rows.map { |r| r[2] }.compact.uniq
    movie_avg = {}
    if movie_ids.any?
      movie_ids.each do |mid|
        avg = Ticket.joins(:showtime).where(showtimes: { movie_id: mid }).where(status: %w[sold Sold]).joins(:showtime).group('showtimes.movie_id').average('count_all') rescue nil
        # fallback: compute total sold / shows
        if avg.nil?
          stats = Ticket.joins(:showtime).where(showtimes: { movie_id: mid }).where(status: %w[sold Sold]).joins(:showtime).group('showtimes.id').count
          movie_avg[mid] = (stats.values.sum.to_f / [stats.size, 1].max)
        else
          movie_avg[mid] = avg.to_f
        end
      end
    end

    rows.map do |id, start_time, movie_id, sold_count|
      movie_pop = movie_avg[movie_id] || 0.0
      movie_obj = Movie.find_by(id: movie_id)
      release_date = (movie_obj && movie_obj.respond_to?(:release_date) ? movie_obj.release_date : nil) || movie_obj&.created_at
      days_since_release = release_date ? (start_time.to_date - release_date.to_date).to_i : nil
      is_weekend = start_time.saturday? || start_time.sunday?

      {
        sold: sold_count.to_i,
        dow: start_time.wday,
        hour: start_time.hour,
        capacity: (hall.rows.to_i * hall.seats_per_row.to_i),
        movie_popularity: movie_pop.to_f,
        is_weekend: is_weekend,
        days_since_release: days_since_release
      }
    end
  end

  def upcoming_showtimes_for(hall, horizon_days)
    # naive: assume showtimes exist in DB (Showtime model) -- pick showtime start times for next horizon
    Showtime.where(hall_id: hall.id).where('start_time >= ? AND start_time <= ?', Time.current, Time.current + horizon_days.days).pluck(:start_time).uniq
  end

  def build_features(hall, showtime_at)
    # Attempt to find a matching showtime record to extract movie/popularity data
    st = Showtime.where(hall_id: hall.id).where(start_time: showtime_at).first
    movie_pop = 0.0
    days_since_release = nil
    is_weekend = showtime_at.saturday? || showtime_at.sunday?

    if st && st.movie_id
      movie_obj = Movie.find_by(id: st.movie_id)
      # movie popularity as historical avg sold per show
      stats = Ticket.joins(:showtime).where(showtimes: { movie_id: st.movie_id }).where(status: %w[sold Sold]).joins(:showtime).group('showtimes.id').count
      movie_pop = stats.values.sum.to_f / [stats.size, 1].max
      release_date = (movie_obj && movie_obj.respond_to?(:release_date) ? movie_obj.release_date : nil) || movie_obj&.created_at
      days_since_release = release_date ? (showtime_at.to_date - release_date.to_date).to_i : nil
    end

    {
      dow: showtime_at.wday,
      hour: showtime_at.hour,
      capacity: (hall.rows.to_i * hall.seats_per_row.to_i),
      movie_popularity: movie_pop.to_f,
      is_weekend: is_weekend,
      days_since_release: days_since_release
    }
  end
end
