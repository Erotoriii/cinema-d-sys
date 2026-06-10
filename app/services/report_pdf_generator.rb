class ReportPdfGenerator
  class MissingDependencyError < StandardError; end

  def initialize(report:)
    @report = report
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

      # Header
      pdf.text safe_text("Звіт про зміну"), size: 20, style: :bold
      pdf.move_down 4

      # General info section
      pdf.text safe_text("Загальне"), size: 14, style: :bold
      pdf.stroke_color "CBD5E1"
      pdf.stroke_horizontal_rule
      pdf.move_down 8

      general_info = [
        ["Кінотеатр:", @report.cinema.name],
        ["Адреса:", @report.cinema.address],
        ["Працівник:", @report.user.name.present? ? @report.user.name : @report.user.email],
        ["Початок зміни:", @report.start_time.strftime("%d/%m/%Y %H:%M")],
        ["Кінець зміни:", @report.end_time.strftime("%d/%m/%Y %H:%M")],
        ["Статус:", Report::STATUS_LABELS[@report.status]],
        ["Продано квитків:", (@report.tickets_count || 0).to_s],
        ["Дохід (квитки):", format_currency(@report.tickets_revenue.to_f)],
        ["Дохід (товари):", format_currency(@report.products_revenue.to_f)],
        ["Загальний дохід:", format_currency(@report.total_revenue.to_f)]
      ]

      general_info.each do |label, value|
        pdf.text safe_text("#{label} #{value}"), size: 11
      end

      pdf.move_down 16

      # Products section
      pdf.text safe_text("Продажі товарів"), size: 14, style: :bold
      pdf.stroke_horizontal_rule
      pdf.move_down 8

      if @report.products_rows.any?
        # Table header
        header_row = ["#", "Продукт", "Кільк.", "Продано", "Ціна/од.", "Дохід"]
        col_widths = { 0 => 25, 1 => 180, 2 => 50, 3 => 50, 4 => 70, 5 => 70 }

        pdf.fill_color "0F172A"
        pdf.text safe_text(header_row.join(" | ")), size: 10, style: :bold
        pdf.stroke_horizontal_rule
        pdf.move_down 4

        # Table rows
        pdf.fill_color "000000"
        @report.products_rows.each_with_index do |row, index|
          line = [
            (index + 1).to_s,
            row["name"].to_s[0..25],
            row["amount"].to_s,
            row["sold"].to_s,
            format_currency(row["unit_price"].to_f),
            format_currency(row["income"].to_f)
          ]
          pdf.text safe_text(line.join(" | ")), size: 10
        end
      else
        pdf.text safe_text("Товари не були продані"), size: 11, style: :italic
      end

      pdf.move_down 16

      # Footer
      pdf.stroke_horizontal_rule
      pdf.move_down 8
      pdf.text safe_text("Дата генерації: #{Time.current.strftime('%d/%m/%Y %H:%M:%S')}"), 
                size: 9, 
                color: "64748B",
                align: :center
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

  def safe_text(text)
    @unicode_font_enabled ? text : text.encode("ASCII", invalid: :replace, undef: :replace, replace: "?")
  end

  def format_currency(amount)
    format("%.2f ₴", amount)
  end
end
