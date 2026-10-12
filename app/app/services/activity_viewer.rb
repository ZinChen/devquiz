# Кто стоит за WebSocket-соединением: аккаунт, гость с идентичностью в куке
# или аноним без неё (последний только смотрит, в списке не появляется).
#
# viewer_key — стабильный ключ строки ActivityPresence. Для гостя это хэш
# guest_token, а не он сам: токен подписывает попытки гостя (см.
# ApplicationController#guest_token), и класть его в БД или рассылать
# подписчикам нельзя.
class ActivityViewer
  attr_reader :user, :guest_token, :guest_identity

  def self.from_request(request, cookies)
    user_id = request.session[:user_id]
    user    = User.find_by(id: user_id) if user_id

    new(
      user:           user,
      guest_token:    cookies.signed[ApplicationController::GUEST_TOKEN_COOKIE],
      guest_identity: GuestIdentity.from_cookie(cookies.signed[ApplicationController::GUEST_IDENTITY_COOKIE])
    )
  end

  def initialize(user: nil, guest_token: nil, guest_identity: nil)
    @user           = user
    @guest_token    = guest_token
    @guest_identity = guest_identity
  end

  # Есть ли у зрителя что показать другим.
  def identified?
    user.present? || guest_identity.present?
  end

  # Скрывший активность не пишется в presence вовсе (см. ActivityPresence.join).
  def visible?
    user ? user.activity_visible? : true
  end

  def key
    return "u:#{user.id}" if user

    # Гость без токена (куку identity поставили, а токен ещё нет) различается
    # по seed: он тоже стабилен для браузера и тоже не секрет.
    source = guest_token.presence || guest_identity&.dig(:avatar_seed)
    "g:#{Digest::SHA256.hexdigest(source.to_s)[0, 16]}" if source
  end
end
