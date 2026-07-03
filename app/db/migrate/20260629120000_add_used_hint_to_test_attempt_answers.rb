class AddUsedHintToTestAttemptAnswers < ActiveRecord::Migration[7.1]
  def change
    add_column :test_attempt_answers, :used_hint, :boolean, default: false, null: false
  end
end
