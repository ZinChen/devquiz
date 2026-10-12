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

  # Из набора полученных ачивок оставляет по одной на лесенку — старшую
  # ступень, одиночные остаются как есть. Так человека видят другие: «Знаток
  # каталога» вместо четырёх ступеней одного и того же. Ключ лесенки —
  # group_name, у одиночной ачивки его нет и ключом служит её slug (то же самое
  # считает SQL в ActivityPresence.achievement_tile_counts — менять вместе).
  def self.top_steps(records)
    records
      .group_by { |a| a.group_name.presence || a.slug }
      .values
      .map { |steps| steps.max_by { |a| [ a.threshold.to_i, a.position ] } }
      .sort_by { |a| [ a.position, a.id ] }
  end

  def grouped?
    group_name.present?
  end
end
