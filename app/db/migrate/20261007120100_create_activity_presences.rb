class CreateActivityPresences < ActiveRecord::Migration[8.1]
  def change
    # «Кто сейчас проходит тест» (#10). Строка — один зритель на одном тесте;
    # живёт, пока открыта страница прохождения, и подчищается по last_seen_at,
    # если вкладку закрыли без сигнала (убитый процесс, обрыв сети).
    create_table :activity_presences do |t|
      # "u:<id>" для аккаунта, "g:<хэш токена>" для гостя: сырой guest_token
      # наружу и в БД не кладём — он подписывает попытки гостя.
      t.string  :viewer_key, null: false
      t.string  :test_slug,  null: false
      t.string  :question_id
      t.bigint  :user_id
      t.string  :guest_name
      t.string  :guest_avatar_seed
      t.datetime :last_seen_at, null: false
      t.timestamps
    end

    add_index :activity_presences, %i[viewer_key test_slug], unique: true
    add_index :activity_presences, :last_seen_at
  end
end
