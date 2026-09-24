class Identity < ApplicationRecord
  belongs_to :user

  validates :provider, :uid, presence: true
  validates :uid, uniqueness: { scope: :provider }

  # Сырые имя/фото от провайдера — обновляются на каждый вход, чтобы кнопка
  # «взять из Google/GitHub» в профиле показывала актуальные данные, а не
  # то, что было на момент первой привязки аккаунта.
  def refresh_raw_from(auth)
    update!(raw_name: auth.info.name, raw_avatar_url: auth.info.image)
  end
end
