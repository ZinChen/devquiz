class AddChallengeModeToTestAttempts < ActiveRecord::Migration[8.1]
  def change
    add_column :test_attempts, :challenge_mode, :string
  end
end
