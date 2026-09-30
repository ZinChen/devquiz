class CreateAchievements < ActiveRecord::Migration[8.1]
  def change
    # Каталог ачивок ведётся в app/config/achievements.yml и синхронизируется
    # сюда через rake achievements:sync — так же, как тесты из tests/.
    # В базе он нужен, чтобы user_achievements ссылались на стабильный id.
    create_table :achievements do |t|
      t.string  :slug,        null: false
      t.string  :title,       null: false
      t.text    :description
      t.string  :icon
      # Группа-лесенка: ачивки одной группы показываются в кабинете одной
      # плиткой с текущей ступенью, а не десятком отдельных плиток.
      t.string  :group_name
      t.integer :threshold
      t.integer :position,    null: false, default: 0
      # Показывать ли ачивку другим пользователям (#10, live-активность).
      # Кандидаты на false — те, что раскрывают поведение, а не результат.
      t.boolean :shareable,   null: false, default: true

      t.timestamps
    end

    add_index :achievements, :slug, unique: true
    add_index :achievements, :group_name
  end
end
