class ApplicationController < ActionController::Base
  inertia_share do
    {
      current_user: current_user_props,
      flash: flash.to_h
    }
  end

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end
  helper_method :current_user

  def current_user_props
    return nil unless current_user
    {
      id:         current_user.id,
      name:       current_user.name,
      email:      current_user.email,
      avatar_url: current_user.avatar_url
    }
  end

  def require_auth
    redirect_to login_path unless current_user
  end
end
