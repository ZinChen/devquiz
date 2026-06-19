class CreateTestAttempts < ActiveRecord::Migration[8.1]
  def change
    create_table :test_attempts do |t|
      t.integer  :user_id
      t.string   :test_slug,       null: false
      t.decimal  :score,           precision: 5, scale: 2, default: 0
      t.integer  :correct_count,   default: 0
      t.integer  :total_questions, default: 0
      t.integer  :time_spent
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps
    end
    add_index :test_attempts, :user_id
    add_index :test_attempts, :test_slug
    add_index :test_attempts, :completed_at
  end
end
