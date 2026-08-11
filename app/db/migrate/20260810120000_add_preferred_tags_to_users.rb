class AddPreferredTagsToUsers < ActiveRecord::Migration[8.0]
  def change
    # NULL, а не [], сознательно: пустой массив означает "экран видел и ничего
    # не выбрал", NULL — "экран ещё не показывали". Без этого различия онбординг
    # показывался бы снова тем, кто нажал "Пропустить".
    add_column :users, :preferred_tags, :jsonb
  end
end
