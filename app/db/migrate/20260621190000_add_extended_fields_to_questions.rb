class AddExtendedFieldsToQuestions < ActiveRecord::Migration[8.1]
  def change
    add_column :questions, :extended_explanation, :text
    add_column :questions, :recommendation, :text
  end
end
