# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_06_25_100000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "bookmarks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "question_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["question_id"], name: "index_bookmarks_on_question_id"
    t.index ["user_id", "question_id"], name: "index_bookmarks_on_user_id_and_question_id", unique: true
    t.index ["user_id"], name: "index_bookmarks_on_user_id"
  end

  create_table "questions", force: :cascade do |t|
    t.jsonb "correct_ids", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "explanation"
    t.text "extended_explanation"
    t.jsonb "options", default: [], null: false
    t.string "question_id", null: false
    t.text "recommendation"
    t.string "test_slug", null: false
    t.text "text", null: false
    t.string "type_field", default: "single", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_questions_on_deleted_at"
    t.index ["test_slug", "question_id"], name: "index_questions_on_test_slug_and_question_id", unique: true
    t.index ["test_slug"], name: "index_questions_on_test_slug"
  end

  create_table "test_attempt_answers", force: :cascade do |t|
    t.integer "attempt_id", null: false
    t.boolean "correct", default: false
    t.datetime "created_at", null: false
    t.string "question_id", null: false
    t.jsonb "selected_options", default: []
    t.datetime "updated_at", null: false
    t.index ["attempt_id"], name: "index_test_attempt_answers_on_attempt_id"
  end

  create_table "test_attempts", force: :cascade do |t|
    t.datetime "completed_at"
    t.integer "correct_count", default: 0
    t.datetime "created_at", null: false
    t.decimal "score", precision: 5, scale: 2, default: "0.0"
    t.datetime "started_at"
    t.string "test_slug", null: false
    t.integer "time_spent"
    t.integer "total_questions", default: 0
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["completed_at"], name: "index_test_attempts_on_completed_at"
    t.index ["test_slug"], name: "index_test_attempts_on_test_slug"
    t.index ["user_id"], name: "index_test_attempts_on_user_id"
  end

  create_table "test_metadata", force: :cascade do |t|
    t.integer "attempts_count", default: 0
    t.decimal "avg_score", precision: 5, scale: 2, default: "0.0"
    t.integer "best_attempt_id"
    t.decimal "best_score", precision: 5, scale: 2
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.string "difficulty"
    t.integer "estimated_time"
    t.string "file_checksum"
    t.decimal "pass_rate", precision: 5, scale: 2, default: "0.0"
    t.integer "questions_count", default: 0
    t.string "slug", null: false
    t.datetime "synced_at"
    t.string "tags", default: "", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["attempts_count"], name: "index_test_metadata_on_attempts_count"
    t.index ["deleted_at"], name: "index_test_metadata_on_deleted_at"
    t.index ["difficulty"], name: "index_test_metadata_on_difficulty"
    t.index ["slug"], name: "index_test_metadata_on_slug", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name"
    t.string "provider", null: false
    t.string "uid", null: false
    t.datetime "updated_at", null: false
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
  end

  add_foreign_key "bookmarks", "questions"
  add_foreign_key "bookmarks", "users"
end
