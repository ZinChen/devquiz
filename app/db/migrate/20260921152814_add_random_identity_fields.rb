class AddRandomIdentityFields < ActiveRecord::Migration[8.1]
  def change
    # Сырые данные от провайдера — отдельно от users.name/avatar_url, которые
    # теперь по умолчанию случайные. Кнопка «взять из Google/GitHub» в профиле
    # достаёт значение отсюда, не трогая OAuth заново.
    add_column :identities, :raw_name,       :string
    add_column :identities, :raw_avatar_url, :string

    # Seed генерируемого SVG-аватара (цвет фона + инициалы/фигура) — рисуется
    # на фронте, чтобы не тащить сторонний сервис вроде Gravatar/DiceBear.
    add_column :users, :avatar_seed, :string
  end
end
