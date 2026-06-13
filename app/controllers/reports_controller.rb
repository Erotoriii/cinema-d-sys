class ReportsController < ApplicationController
  before_action :authorize_manager!
  before_action :set_report, only: [:show, :update, :download]

  def index
    @reports = scoped_reports.includes(workday: [:cinema, :user]).order(created_at: :desc).limit(100)
  end

  def show
  end

  def update
    if @report.update(report_params)
      redirect_to report_path(@report), notice: "Report status updated successfully."
    else
      render :show, status: :unprocessable_entity
    end
  end

  def download
    begin
      pdf_data = ReportPdfGenerator.new(report: @report).render
      send_data(
        pdf_data,
        filename: pdf_filename_for(@report),
        type: "application/pdf",
        disposition: "attachment"
      )
    rescue ReportPdfGenerator::MissingDependencyError => e
      Rails.logger.error("PDF generation failed: #{e.message}")
      flash[:alert] = "PDF генерація тимчасово недоступна на цьому сервері."
      redirect_to report_path(@report)
    end
  end

  private

  def scoped_reports
    ReportScopeService.new(
      current_user: current_user,
      current_workday: current_workday
    ).scoped_reports
  end

  def set_report
    @report = scoped_reports.includes(workday: [:cinema, :user]).find(params[:id])
  end

  def report_params
    params.require(:report).permit(:status)
  end

  def pdf_filename_for(report)
    cinema_name = report.cinema.name.parameterize
    date = report.created_at.strftime("%Y%m%d")
    "report_#{cinema_name}_#{date}_#{report.id}.pdf"
  end
end