# Строка каталога ачивок. Источник правды — config/achievements.yml, здесь
# запись нужна только чтобы user_achievements ссылались на стабильный id
# (см. AchievementsCatalog.sync!).
class Achievement < ApplicationRecord
  has_many :user_achievements, dependent: :destroy
  has_many :users, through: :user_achievements

  validates :slug,  presence: true, uniqueness: true
  validates :title, presence: true

  scope :shareable, -> { where(shareable: true) }
  scope :ordered,   -> { order(:position, :id) }

  # Ступени одной лесенки — от младшей к старшей.
  scope :in_group, ->(name) { where(group_name: name).order(:threshold) }

  def grouped?
    group_name.present?
  end
end
