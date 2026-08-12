class SessionsController < ApplicationController
  def new
    render inertia: "Sessions/New"
  end

  def create
    auth = request.env["omniauth.auth"]
    user = User.from_omniauth(auth)

    # Гостевое состояние читаем до reset_session — он сбрасывает подписанные куки.
    token      = guest_token
    guest_tags = preferred_tags

    reset_session
    session[:user_id] = user.id

    claim_guest_attempts(user, token)
    adopt_guest_preferences(user, guest_tags)

    redirect_to root_path, notice: "Добро пожаловать, #{user.name.presence || user.email}!"
  rescue User::OmniauthError, ActiveRecord::RecordInvalid => e
    redirect_to login_path, alert: "Не удалось войти: #{e.message}"
  end

  def failure
    redirect_to login_path, alert: "Вход через провайдера отменён или не удался."
  end

  def destroy
    # Темы из профиля переносим в гостевую куку до сброса сессии: иначе после
    # выхода пользователь снова попадал бы на экран первичного выбора тем.
    tags = current_user&.preferred_tags

    reset_session
    # Сбрасываем мемоизацию: иначе preferred_tags= увидит прежнего юзера
    # и запишет темы обратно в профиль вместо гостевой куки.
    @current_user = nil
    self.preferred_tags = tags if tags

    redirect_to root_path, notice: "Вы вышли из аккаунта."
  end

  private

  # Попытки, пройденные до входа, достаются владельцу аккаунта. Дубликаты по
  # тому же тесту не схлопываем: история и так многозаписная, а best_score
  # считается по максимуму.
  def claim_guest_attempts(user, token)
    return if token.blank?

    TestAttempt.where(user_id: nil, guest_token: token)
               .update_all(user_id: user.id, guest_token: nil)
    cookies.delete(GUEST_TOKEN_COOKIE)
  end

  # Выбор, сделанный до логина, переносим только если у аккаунта его ещё нет —
  # иначе первый же вход со старого устройства затёр бы настройки профиля.
  def adopt_guest_preferences(user, tags)
    user.update!(preferred_tags: TagTaxonomy.sanitize(tags)) if tags.present? && user.preferred_tags.nil?
    cookies.delete(PREFERRED_TAGS_COOKIE)
  end
end
