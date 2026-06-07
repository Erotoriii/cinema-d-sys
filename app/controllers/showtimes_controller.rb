class ShowtimesController < ApplicationController
  before_action :set_showtime, only: [:show, :edit, :update, :destroy]
  before_action :authorize_manager!, except: [:index, :show]

  # GET /showtimes
  def index
    if current_workday
      # If user has an active shift, show only showtimes from that cinema
      @showtimes = Showtime.joins(:hall).where(halls: { cinema_id: current_workday.cinema_id })
                           .includes(:movie, hall: :cinema).order(:start_time)
    elsif current_user.admin_or_manager?
      cinema_ids = current_user.company&.cinema_ids || []
      # Admins and managers can see all showtimes ONLY FOR THEIR COMPANY
      @showtimes = Showtime.joins(:hall)
                           .where(halls: { cinema_id: cinema_ids })
                           .includes(:movie, hall: :cinema).order(:start_time)
    else
      # Staff without active shift cannot view showtimes
      @showtimes = []
      flash.now[:alert] = "Please start a shift first to view showtimes."
    end
  end

  # GET /showtimes/:id
  def show
  end

  # GET /showtimes/new
  def new
    @showtime = Showtime.new
    @showtime.batch_date = Date.current
    cinema_ids = current_user.company&.cinema_ids || []
    @existing_showtimes = Showtime.joins(:hall)
                                 .where(halls: { cinema_id: cinema_ids })
                                 .includes(:movie, hall: :cinema)
                                 .order(:start_time)
                                 .limit(40)
  end

  # POST /showtimes
  def create
    @showtime = Showtime.new(showtime_params.except(:batch_date, :batch_times_text))

    if batch_creation_requested?
      batch_entries = parse_batch_entries(showtime_params[:batch_date], showtime_params[:batch_times_text])
      apply_first_batch_time!(@showtime, batch_entries)
      created = create_batch_showtimes(@showtime, batch_entries)
      if created.any?
        redirect_to showtimes_path, notice: "Створено #{created.size} сеанс(ів)."
      else
        @showtime.errors.add(:base, "Не вдалося створити жодного сеансу. Перевірте часи та чи не існують вони вже в цьому залі.")
        render :new, status: :unprocessable_entity
      end
    elsif @showtime.save
      redirect_to @showtime, notice: "Showtime was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # GET /showtimes/:id/edit
  def edit
  end

  # PATCH/PUT /showtimes/:id
  def update
    if @showtime.update(showtime_params)
      redirect_to @showtime, notice: "Showtime was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /showtimes/:id
  def destroy
    @showtime.destroy
    redirect_to showtimes_url, notice: "Showtime was successfully deleted."
  end

  private

  def set_showtime
    @showtime = Showtime.find(params[:id])
  end

  def showtime_params
    params.require(:showtime).permit(:movie_id, :hall_id, :start_time, :price, :batch_date, :batch_times_text)
  end

  def authorize_manager!
    redirect_to showtimes_url, alert: "Not authorized." unless current_user&.admin_or_manager?
  end

  def batch_creation_requested?
    showtime_params[:batch_date].present? && showtime_params[:batch_times_text].present?
  end

  def apply_first_batch_time!(showtime, batch_entries)
    first_entry = batch_entries.first
    return if first_entry.nil?

    parsed_time = first_entry[:start_time]
    showtime.start_time = parsed_time if parsed_time && showtime.start_time.blank?
  end

  def parse_batch_entries(batch_date, times_text)
    date = Date.parse(batch_date.to_s) rescue nil
    return [] if date.nil?

    tokens = times_text.to_s.split(/[\n,;]+/).map(&:strip).reject(&:blank?)
    tokens.filter_map do |token|
      time_part, price_part = token.split(/\s*[\|=]\s*/, 2)
      time_part ||= token
      parsed_time = Time.zone.parse("#{date} #{time_part}") rescue nil
      next if parsed_time.nil?

      parsed_price = if price_part.present?
        price_part.to_s.gsub(/[^\d.,]/, "").tr(",", ".").to_d
      end

      { start_time: parsed_time, price: parsed_price }
    end
  end

  def create_batch_showtimes(base_showtime, batch_entries)
    created = []
    batch_entries.each do |entry|
      parsed_time = entry[:start_time]
      next if Showtime.exists?(hall_id: base_showtime.hall_id, start_time: parsed_time)

      created << Showtime.create(
        movie_id: base_showtime.movie_id,
        hall_id: base_showtime.hall_id,
        start_time: parsed_time,
        price: entry[:price].presence || base_showtime.price
      )
    end

    created.select(&:persisted?)
  end
end
