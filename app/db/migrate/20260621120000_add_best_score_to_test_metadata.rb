class AddBestScoreToTestMetadata < ActiveRecord::Migration[8.0]
  def change
    add_column :test_metadata, :best_score, :decimal, precision: 5, scale: 2
    add_column :test_metadata, :best_attempt_id, :integer
  end
end
