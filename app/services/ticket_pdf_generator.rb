class TicketPdfGenerator
  class MissingDependencyError < StandardError; end

  def initialize(showtime:, tickets:)
    @showtime = showtime
    @tickets = tickets.sort_by { |ticket| [ticket.seat.row, ticket.seat.number] }
    @unicode_font_enabled = false
  end

  def render
    begin
      require "prawn"
    rescue LoadError => e
      raise MissingDependencyError, "PDF generation library is unavailable: #{e.message}"
    end

    Prawn::Document.new(page_size: "A4", margin: 32) do |pdf|
      configure_font!(pdf)

      pdf.text safe_text("Cinema Ticket Batch"), size: 22, style: :bold
      pdf.move_down 8

      pdf.text safe_text("Movie: #{@showtime.movie.title}"), size: 12
      pdf.text safe_text("Date: #{@showtime.start_time.strftime('%Y-%m-%d %H:%M')}"), size: 12
      pdf.text safe_text("Hall: #{@showtime.hall.name}"), size: 12
      pdf.text safe_text("Price: #{@showtime.price} UAH"), size: 12
      pdf.move_down 14

      pdf.fill_color "0F172A"
      pdf.text safe_text("# | Row | Seat | Status | Issued At"), size: 10, style: :bold
      pdf.stroke_color "CBD5E1"
      pdf.stroke_horizontal_rule
      pdf.move_down 8

      @tickets.each_with_index do |ticket, index|
        line = [
          (index + 1).to_s.rjust(2),
          ticket.seat.row.to_s.rjust(3),
          ticket.seat.number.to_s.rjust(4),
          ticket.status.to_s.upcase.ljust(8),
          ticket.updated_at.strftime("%Y-%m-%d %H:%M")
        ].join(" | ")

        pdf.text safe_text(line), size: 10
      end

      pdf.move_down 16
      total = @tickets.count * @showtime.price.to_f
      pdf.text safe_text("Total tickets: #{@tickets.count}"), size: 12, style: :bold
      pdf.text safe_text("Total amount: #{format('%.2f', total)} UAH"), size: 12, style: :bold
    end.render
  end

  private

  def configure_font!(pdf)
    font_regular = unicode_font_candidates.find { |path| File.exist?(path) }
    font_bold = unicode_bold_font_candidates.find { |path| File.exist?(path) }

    return unless font_regular

    pdf.font_families.update(
      "AppUnicode" => {
        normal: font_regular,
        bold: font_bold || font_regular
      }
    )
    pdf.font("AppUnicode")
    @unicode_font_enabled = true
  end

  def unicode_font_candidates
    [
      Rails.root.join("app/assets/fonts/DejaVuSans.ttf").to_s,
      "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
      "/usr/share/fonts/dejavu/DejaVuSans.ttf"
    ]
  end

  def unicode_bold_font_candidates
    [
      Rails.root.join("app/assets/fonts/DejaVuSans-Bold.ttf").to_s,
      "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
      "/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf"
    ]
  end

  def safe_text(value)
    text = value.to_s
    return text if @unicode_font_enabled

    text.encode("Windows-1252", invalid: :replace, undef: :replace, replace: "?")
  end
end
