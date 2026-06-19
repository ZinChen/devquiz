class TestAttempt < ApplicationRecord
  belongs_to :user, optional: true
  has_many   :test_attempt_answers, foreign_key: :attempt_id

  validates :test_slug, presence: true

  def completed?
    completed_at.present?
  end

  def percentage
    return 0 if total_questions.to_i.zero?
    (correct_count.to_f / total_questions * 100).round(1)
  end
end
