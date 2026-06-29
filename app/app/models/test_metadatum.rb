class TestMetadatum < ApplicationRecord
  self.table_name = "test_metadata"

  has_many :test_attempts, foreign_key: :test_slug, primary_key: :slug

  scope :active, -> { where(deleted_at: nil) }

  validates :slug, :title, presence: true
  validates :slug, uniqueness: true

  def soft_delete!
    update_column(:deleted_at, Time.current)
  end

  def deleted?
    deleted_at.present?
  end

  def tag_list
    tags.to_s.split(",").map(&:strip)
  end

  def tag_list=(arr)
    self.tags = Array(arr).join(",")
  end

  def completed_challenge_mode_list
    completed_challenge_modes.to_s.split(",").map(&:strip).reject(&:empty?)
  end

  def add_completed_challenge_mode!(mode)
    current = completed_challenge_mode_list
    return if current.include?(mode)
    update_column(:completed_challenge_modes, (current + [mode]).join(","))
  end
end
