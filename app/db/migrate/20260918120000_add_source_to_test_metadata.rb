class AddSourceToTestMetadata < ActiveRecord::Migration[8.1]
  def change
    # Откуда пришёл тест: "repo" (папка tests/ в гите) или "custom"
    # (tests_custom/, локальная и не трекается).
    add_column :test_metadata, :source, :string, null: false, default: "repo"
    # Кастомный файл занял слаг репозиторного — законная подмена, но о ней
    # предупреждаем на карточке теста.
    add_column :test_metadata, :overrides_repo, :boolean, null: false, default: false

    add_index :test_metadata, :source
  end
end
