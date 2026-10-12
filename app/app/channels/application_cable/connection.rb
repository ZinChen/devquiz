module ApplicationCable
  # Сессия и гостевые куки читаются теми же ключами, что в ApplicationController
  # (session[:user_id], GUEST_TOKEN_COOKIE, GUEST_IDENTITY_COOKIE): канал не
  # заводит своей аутентификации, а повторяет то, кем браузер уже считается.
  # Подключиться может любой, в том числе без куки — список активности публичен,
  # а вот участвовать в нём (join) можно только с идентичностью.
  class Connection < ActionCable::Connection::Base
    identified_by :viewer

    def connect
      self.viewer = ActivityViewer.from_request(request, cookies)
    end
  end
end
