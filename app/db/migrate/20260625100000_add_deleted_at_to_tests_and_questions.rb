class AddDeletedAtToTestsAndQuestions < ActiveRecord::Migration[8.1]
  def change
    add_column :test_metadata, :deleted_at, :datetime
    add_column :questions, :deleted_at, :datetime

    add_index :test_metadata, :deleted_at
    add_index :questions, :deleted_at
  end
end
