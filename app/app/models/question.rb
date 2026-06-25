class Question < ApplicationRecord
  has_many :bookmarks, dependent: :destroy

  scope :active, -> { where(deleted_at: nil) }

  validates :test_slug, :question_id, :text, presence: true
  validates :question_id, uniqueness: { scope: :test_slug }

  def soft_delete!
    update_column(:deleted_at, Time.current)
  end
end
