class UserAchievement < ApplicationRecord
  belongs_to :user
  belongs_to :achievement

  validates :user_id, uniqueness: { scope: :achievement_id }

  scope :recent_first, -> { order(earned_at: :desc) }
end
