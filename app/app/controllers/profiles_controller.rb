class ProfilesController < ApplicationController
  before_action :require_auth

  def update
    current_user.update!(profile_params.compact_blank)
    redirect_back fallback_location: dashboard_path
  end

  private

  def profile_params
    params.permit(:name, :avatar_url)
  end
end
