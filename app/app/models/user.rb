class User < ApplicationRecord
  has_many :identities, dependent: :destroy
  has_many :test_attempts, foreign_key: :user_id
  has_many :bookmarks, dependent: :destroy
  has_many :bookmarked_questions, through: :bookmarks, source: :question
  has_many :user_achievements, dependent: :destroy
  has_many :achievements, through: :user_achievements

  validates :email, presence: true
  validates :name, presence: true, length: { maximum: 60 }
  validates :avatar_url, length: { maximum: 2048 }, allow_blank: true
  validate  :avatar_url_must_be_http

  # Пустая ссылка — осмысленное действие («вернуться к сгенерированному
  # аватару»), поэтому разрешена. Непустая обязана быть http(s): это не
  # эстетика, а защита от javascript:/data: URI, если когда-нибудь рендер
  # сменится с безопасного <img :src> на что-то менее строгое (v-html,
  # подстановка в <a href> и т.п.) — тогда схема URL уже не будет
  # нейтрализована самим способом рендера.
  def avatar_url_must_be_http
    return if avatar_url.blank?

    uri = URI.parse(avatar_url)
    errors.add(:avatar_url, "должна начинаться с http:// или https://") unless uri.is_a?(URI::HTTP)
  rescue URI::InvalidURIError
    errors.add(:avatar_url, "недействительная ссылка")
  end

  # Находит или создаёт пользователя по данным OmniAuth.
  #
  # Аккаунты из разных провайдеров склеиваются в один, если совпадает email,
  # но только когда провайдер подтвердил владение адресом — иначе чужой
  # аккаунт можно было бы захватить, зарегистрировав почту без подтверждения.
  #
  # guest_identity — {name:, avatar_seed:} из гостевой куки текущего браузера
  # (см. GuestIdentity): если под этим именем/аватаром уже проходили тесты
  # анонимно, аккаунт продолжает называться так же, а не получает новую
  # случайную пару — иначе смена имени в момент логина выглядела бы как сбой.
  # Применяется только к только что созданному аккаунту: у существующего
  # пользователя уже есть свои name/avatar_seed, которые нельзя затирать.
  def self.from_omniauth(auth, guest_identity: nil)
    email = auth.info.email.to_s.strip.downcase
    raise OmniauthError, "Провайдер не вернул email" if email.blank?

    transaction do
      identity = Identity.find_by(provider: auth.provider, uid: auth.uid)
      if identity
        identity.refresh_raw_from(auth)
        next identity.user
      end

      user = find_by_email(email)

      if user
        raise OmniauthError, "Email не подтверждён провайдером" unless email_verified?(auth)
      else
        # Имя и фото — случайные (или унаследованные от гостя), а не из auth:
        # пользователь сам решает, показывать ли настоящие (см. RandomIdentity,
        # DashboardController#update — там же меняется профиль).
        user = create!(
          email:       email,
          name:        guest_identity&.dig(:name) || RandomIdentity.name,
          avatar_seed: guest_identity&.dig(:avatar_seed) || RandomIdentity.avatar_seed
        )
      end

      identity = user.identities.create!(provider: auth.provider, uid: auth.uid)
      identity.refresh_raw_from(auth)
      user
    end
  end

  def self.find_by_email(email)
    where("lower(email) = ?", email.to_s.strip.downcase).first
  end

  # Google отдаёт явный флаг подтверждения. GitHub со scope "user:email"
  # возвращает только verified primary email, поэтому там подтверждение неявное.
  def self.email_verified?(auth)
    case auth.provider.to_s
    when "google_oauth2" then auth.extra&.raw_info&.email_verified.to_s == "true"
    when "github"        then true
    else false
    end
  end

  def connected_providers
    identities.pluck(:provider)
  end

  class OmniauthError < StandardError; end
end
