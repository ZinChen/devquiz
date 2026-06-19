class CreateTestAttemptAnswers < ActiveRecord::Migration[8.1]
  def change
    create_table :test_attempt_answers do |t|
      t.integer :attempt_id,       null: false
      t.string  :question_id,      null: false
      t.jsonb   :selected_options, default: []
      t.boolean :correct,          default: false
      t.timestamps
    end
    add_index :test_attempt_answers, :attempt_id
  end
end
