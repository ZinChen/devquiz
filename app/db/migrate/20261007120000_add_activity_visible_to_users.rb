class AddActivityVisibleToUsers < ActiveRecord::Migration[8.1]
  def change
    # Показывать ли пользователя другим в live-активности (#9, #10): аватарка
    # в списке тестов и на экране прохождения. По умолчанию видим — гости,
    # у которых колонки нет, тоже видны, поэтому и для аккаунтов это норма.
    add_column :users, :activity_visible, :boolean, null: false, default: true
  end
end
