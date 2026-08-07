class User < ApplicationRecord
  has_many :identities, dependent: :destroy
  has_many :test_attempts, foreign_key: :user_id
  has_many :bookmarks, dependent: :destroy
  has_many :bookmarked_questions, through: :bookmarks, source: :question

  validates :email, presence: true

  # Находит или создаёт пользователя по данным OmniAuth.
  #
  # Аккаунты из разных провайдеров склеиваются в один, если совпадает email,
  # но только когда провайдер подтвердил владение адресом — иначе чужой
  # аккаунт можно было бы захватить, зарегистрировав почту без подтверждения.
  def self.from_omniauth(auth)
    email = auth.info.email.to_s.strip.downcase
    raise OmniauthError, "Провайдер не вернул email" if email.blank?

    transaction do
      identity = Identity.find_by(provider: auth.provider, uid: auth.uid)
      next identity.user.tap { |u| u.refresh_profile_from(auth) } if identity

      user = find_by_email(email)

      if user
        raise OmniauthError, "Email не подтверждён провайдером" unless email_verified?(auth)
        user.refresh_profile_from(auth)
      else
        user = create!(
          email:      email,
          name:       auth.info.name,
          avatar_url: auth.info.image
        )
      end

      user.identities.create!(provider: auth.provider, uid: auth.uid)
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

  # Обновляет пустые поля профиля данными свежего входа, не затирая заполненные.
  def refresh_profile_from(auth)
    self.name       = auth.info.name  if name.blank?
    self.avatar_url = auth.info.image if avatar_url.blank?
    save! if changed?
    self
  end

  def connected_providers
    identities.pluck(:provider)
  end

  class OmniauthError < StandardError; end
end
