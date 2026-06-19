class SessionsController < ApplicationController
  def new
    render inertia: "Sessions/New"
  end

  def create
    auth = request.env["omniauth.auth"]
    user = User.from_omniauth(auth)
    session[:user_id] = user.id
    redirect_to root_path, notice: "Добро пожаловать, #{user.name}!"
  end

  def destroy
    session[:user_id] = nil
    redirect_to root_path, notice: "Вы вышли из аккаунта."
  end
end
