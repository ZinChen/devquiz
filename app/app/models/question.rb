class Question < ApplicationRecord
  has_many :bookmarks, dependent: :destroy

  validates :test_slug, :question_id, :text, presence: true
  validates :question_id, uniqueness: { scope: :test_slug }
end
