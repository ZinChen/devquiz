class User < ApplicationRecord
  has_many :test_attempts, foreign_key: :user_id

  validates :provider, :uid, presence: true
  validates :uid, uniqueness: { scope: :provider }

  def self.from_omniauth(auth)
    find_or_create_by(provider: auth.provider, uid: auth.uid) do |u|
      u.email      = auth.info.email
      u.name       = auth.info.name
      u.avatar_url = auth.info.image
    end
  end
end
