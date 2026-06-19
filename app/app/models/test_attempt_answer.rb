class TestAttemptAnswer < ApplicationRecord
  belongs_to :test_attempt, foreign_key: :attempt_id

  validates :question_id, presence: true
end
