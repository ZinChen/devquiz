class CreateIdentities < ActiveRecord::Migration[8.1]
  def up
    create_table :identities do |t|
      t.references :user, null: false, foreign_key: true
      t.string :provider, null: false
      t.string :uid,      null: false
      t.timestamps
    end
    add_index :identities, [ :provider, :uid ], unique: true

    execute <<~SQL
      INSERT INTO identities (user_id, provider, uid, created_at, updated_at)
      SELECT id, provider, uid, created_at, updated_at FROM users
    SQL

    # Слить дубликаты: пользователи с одинаковым email становятся одним аккаунтом.
    # Победитель — самый старый (минимальный id), к нему переезжают identity и данные.
    execute <<~SQL
      CREATE TEMP TABLE user_merges AS
      SELECT u.id AS loser_id, k.keeper_id
      FROM users u
      JOIN (
        SELECT lower(email) AS email, MIN(id) AS keeper_id
        FROM users
        WHERE email IS NOT NULL AND email <> ''
        GROUP BY lower(email)
        HAVING COUNT(*) > 1
      ) k ON lower(u.email) = k.email
      WHERE u.id <> k.keeper_id
    SQL

    execute "UPDATE identities i SET user_id = m.keeper_id FROM user_merges m WHERE i.user_id = m.loser_id"
    execute "UPDATE test_attempts t SET user_id = m.keeper_id FROM user_merges m WHERE t.user_id = m.loser_id"

    # У bookmarks уникальный индекс (user_id, question_id) — сначала убираем те,
    # что после слияния станут дубликатами, потом переносим остальные.
    execute <<~SQL
      DELETE FROM bookmarks b
      USING user_merges m
      WHERE b.user_id = m.loser_id
        AND EXISTS (
          SELECT 1 FROM bookmarks kept
          WHERE kept.user_id = m.keeper_id AND kept.question_id = b.question_id
        )
    SQL
    execute "UPDATE bookmarks b SET user_id = m.keeper_id FROM user_merges m WHERE b.user_id = m.loser_id"

    execute "DELETE FROM users WHERE id IN (SELECT loser_id FROM user_merges)"
    execute "DROP TABLE user_merges"

    remove_index :users, column: [ :provider, :uid ]
    remove_column :users, :provider
    remove_column :users, :uid

    add_index :users, "lower(email)", unique: true, name: "index_users_on_lower_email", where: "email IS NOT NULL AND email <> ''"
  end

  def down
    remove_index :users, name: "index_users_on_lower_email"
    add_column :users, :provider, :string
    add_column :users, :uid, :string

    execute <<~SQL
      UPDATE users u
      SET provider = i.provider, uid = i.uid
      FROM (
        SELECT DISTINCT ON (user_id) user_id, provider, uid
        FROM identities ORDER BY user_id, id
      ) i
      WHERE u.id = i.user_id
    SQL

    execute "DELETE FROM users WHERE provider IS NULL OR uid IS NULL"
    change_column_null :users, :provider, false
    change_column_null :users, :uid, false
    add_index :users, [ :provider, :uid ], unique: true

    drop_table :identities
  end
end
