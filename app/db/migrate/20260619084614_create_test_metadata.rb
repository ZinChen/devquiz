class CreateTestMetadata < ActiveRecord::Migration[8.1]
  def change
    create_table :test_metadata do |t|
      t.string  :slug,           null: false
      t.string  :title,          null: false
      t.text    :description
      t.string  :tags,           default: "", null: false
      t.string  :difficulty
      t.integer :estimated_time
      t.integer :questions_count, default: 0
      t.string  :file_checksum
      t.datetime :synced_at
      t.integer :attempts_count,  default: 0
      t.decimal :avg_score,       precision: 5, scale: 2, default: 0
      t.decimal :pass_rate,       precision: 5, scale: 2, default: 0
      t.timestamps
    end
    add_index :test_metadata, :slug, unique: true
    add_index :test_metadata, :difficulty
    add_index :test_metadata, :attempts_count
  end
end
