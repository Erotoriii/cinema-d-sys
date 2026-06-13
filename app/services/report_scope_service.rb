class ReportScopeService
  def initialize(current_user:, current_workday: nil)
    @current_user = current_user
    @current_workday = current_workday
  end

  def scoped_reports
    reports = base_reports
    reports = filter_by_workday(reports) if current_workday.present?
    reports
  end

  private

  attr_reader :current_user, :current_workday

  def base_reports
    if global_admin?
      Report.all
    else
      Report.joins(workday: :cinema).where(cinemas: { company_id: current_user.company_id })
    end
  end

  def filter_by_workday(reports)
    reports.joins(:workday).where(workdays: { cinema_id: current_workday.cinema_id })
  end

  def global_admin?
    current_user.admin? && current_user.company.nil?
  end
end
