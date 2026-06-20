class CreateQuestions < ActiveRecord::Migration[8.1]
  def change
    create_table :questions do |t|
      t.string  :test_slug,   null: false
      t.string  :question_id, null: false
      t.text    :text,        null: false
      t.string  :type_field,  null: false, default: "single"
      t.jsonb   :options,     null: false, default: []
      t.jsonb   :correct_ids, null: false, default: []
      t.text    :explanation

      t.timestamps
    end

    add_index :questions, [:test_slug, :question_id], unique: true
    add_index :questions, :test_slug
  end
end
