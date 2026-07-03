class AddHasCodeChallengeToTestMetadata < ActiveRecord::Migration[7.1]
  def change
    add_column :test_metadata, :has_code_challenge, :boolean, default: false, null: false
  end
end
