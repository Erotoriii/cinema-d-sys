class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  before_action :authenticate_user!
  
  helper_method :current_workday

  private

  # Метод для перевірки, чи є користувач адміном
  def authorize_admin!
    redirect_to root_path, alert: "Доступ дозволено лише адміністратору." unless current_user.admin?
  end

  # Метод для перевірки, чи є користувач адміном або менеджером
  def authorize_manager!
    redirect_to root_path, alert: "У вас недостатньо прав для цієї дії." unless current_user.admin? || current_user.manager?
  end

  # Метод для перевірки, чи може користувач керувати фільмами (адмін або менеджер)
  def authorize_movie_access!
    redirect_to root_path, alert: "У вас недостатньо прав для цієї дії." unless current_user&.admin_or_manager?
  end

  # Returns the active workday (shift) for the current user
  def current_workday
    @current_workday ||= current_user&.workdays&.where(end_time: nil)&.last
  end

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes
end
