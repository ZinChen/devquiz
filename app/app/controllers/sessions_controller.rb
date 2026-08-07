class SessionsController < ApplicationController
  def new
    render inertia: "Sessions/New"
  end

  def create
    auth = request.env["omniauth.auth"]
    user = User.from_omniauth(auth)

    reset_session
    session[:user_id] = user.id
    redirect_to root_path, notice: "Добро пожаловать, #{user.name.presence || user.email}!"
  rescue User::OmniauthError, ActiveRecord::RecordInvalid => e
    redirect_to login_path, alert: "Не удалось войти: #{e.message}"
  end

  def failure
    redirect_to login_path, alert: "Вход через провайдера отменён или не удался."
  end

  def destroy
    reset_session
    redirect_to root_path, notice: "Вы вышли из аккаунта."
  end
end
