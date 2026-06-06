class ReportsController < ApplicationController
  before_action :authorize_manager!
  before_action :set_report, only: [:show, :update, :download]

  def index
    @reports = scoped_reports.includes(workday: [:cinema, :user]).order(created_at: :desc)
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
    html = render_to_string(:download, layout: false)
    send_data html,
              filename: "report-#{@report.id}.html",
              type: "text/html",
              disposition: "attachment"
  end

  private

  def scoped_reports
    return Report.all if current_user.admin? && current_user.company.nil?

    Report.joins(workday: :cinema).where(cinemas: { company_id: current_user.company_id })
  end

  def set_report
    @report = scoped_reports.includes(workday: [:cinema, :user]).find(params[:id])
  end

  def report_params
    params.require(:report).permit(:status)
  end
end