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

ActiveRecord::Schema[7.1].define(version: 2022_10_18_204255) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "author_histories", force: :cascade do |t|
    t.integer "author_id", null: false
    t.string "full_name", null: false
    t.text "bio"
    t.datetime "deleted_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.datetime "history_started_at", precision: nil, null: false
    t.datetime "history_ended_at", precision: nil
    t.integer "history_user_id"
    t.index ["author_id"], name: "index_author_histories_on_author_id"
    t.index ["deleted_at"], name: "index_author_histories_on_deleted_at"
    t.index ["history_ended_at"], name: "index_author_histories_on_history_ended_at"
    t.index ["history_started_at"], name: "index_author_histories_on_history_started_at"
    t.index ["history_user_id"], name: "index_author_histories_on_history_user_id"
  end

  create_table "authors", force: :cascade do |t|
    t.string "full_name", null: false
    t.text "bio"
    t.datetime "deleted_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["deleted_at"], name: "index_authors_on_deleted_at"
  end

  create_table "post_histories", force: :cascade do |t|
    t.integer "post_id", null: false
    t.string "title", null: false
    t.text "body", null: false
    t.integer "author_id", null: false
    t.boolean "enabled", default: false
    t.datetime "live_at", precision: nil
    t.datetime "deleted_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.datetime "history_started_at", precision: nil, null: false
    t.datetime "history_ended_at", precision: nil
    t.integer "history_user_id"
    t.index ["author_id"], name: "index_post_histories_on_author_id"
    t.index ["deleted_at"], name: "index_post_histories_on_deleted_at"
    t.index ["enabled"], name: "index_post_histories_on_enabled"
    t.index ["history_ended_at"], name: "index_post_histories_on_history_ended_at"
    t.index ["history_started_at"], name: "index_post_histories_on_history_started_at"
    t.index ["history_user_id"], name: "index_post_histories_on_history_user_id"
    t.index ["live_at"], name: "index_post_histories_on_live_at"
    t.index ["post_id"], name: "index_post_histories_on_post_id"
  end

  create_table "posts", force: :cascade do |t|
    t.string "title", null: false
    t.text "body", null: false
    t.integer "author_id", null: false
    t.boolean "enabled", default: false
    t.datetime "live_at", precision: nil
    t.datetime "deleted_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["author_id"], name: "index_posts_on_author_id"
    t.index ["deleted_at"], name: "index_posts_on_deleted_at"
    t.index ["enabled"], name: "index_posts_on_enabled"
    t.index ["live_at"], name: "index_posts_on_live_at"
  end

  create_table "safe_post_histories", force: :cascade do |t|
    t.integer "safe_post_id", null: false
    t.string "title", null: false
    t.text "body", null: false
    t.integer "author_id", null: false
    t.boolean "enabled", default: false
    t.datetime "live_at", precision: nil
    t.datetime "deleted_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.datetime "history_started_at", precision: nil, null: false
    t.datetime "history_ended_at", precision: nil
    t.integer "history_user_id"
    t.index ["author_id"], name: "index_safe_post_histories_on_author_id"
    t.index ["deleted_at"], name: "index_safe_post_histories_on_deleted_at"
    t.index ["enabled"], name: "index_safe_post_histories_on_enabled"
    t.index ["history_ended_at"], name: "index_safe_post_histories_on_history_ended_at"
    t.index ["history_started_at"], name: "index_safe_post_histories_on_history_started_at"
    t.index ["history_user_id"], name: "index_safe_post_histories_on_history_user_id"
    t.index ["live_at"], name: "index_safe_post_histories_on_live_at"
    t.index ["safe_post_id"], name: "index_safe_post_histories_on_safe_post_id"
  end

  create_table "safe_posts", force: :cascade do |t|
    t.string "title", null: false
    t.text "body", null: false
    t.integer "author_id", null: false
    t.boolean "enabled", default: false
    t.datetime "live_at", precision: nil
    t.datetime "deleted_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["author_id"], name: "index_safe_posts_on_author_id"
    t.index ["deleted_at"], name: "index_safe_posts_on_deleted_at"
    t.index ["enabled"], name: "index_safe_posts_on_enabled"
    t.index ["live_at"], name: "index_safe_posts_on_live_at"
  end

  create_table "silent_post_histories", force: :cascade do |t|
    t.integer "silent_post_id", null: false
    t.string "title", null: false
    t.text "body", null: false
    t.integer "author_id", null: false
    t.boolean "enabled", default: false
    t.datetime "live_at", precision: nil
    t.datetime "deleted_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.datetime "history_started_at", precision: nil, null: false
    t.datetime "history_ended_at", precision: nil
    t.integer "history_user_id"
    t.index ["author_id"], name: "index_silent_post_histories_on_author_id"
    t.index ["deleted_at"], name: "index_silent_post_histories_on_deleted_at"
    t.index ["enabled"], name: "index_silent_post_histories_on_enabled"
    t.index ["history_ended_at"], name: "index_silent_post_histories_on_history_ended_at"
    t.index ["history_started_at"], name: "index_silent_post_histories_on_history_started_at"
    t.index ["history_user_id"], name: "index_silent_post_histories_on_history_user_id"
    t.index ["live_at"], name: "index_silent_post_histories_on_live_at"
    t.index ["silent_post_id"], name: "index_silent_post_histories_on_silent_post_id"
  end

  create_table "silent_posts", force: :cascade do |t|
    t.string "title", null: false
    t.text "body", null: false
    t.integer "author_id", null: false
    t.boolean "enabled", default: false
    t.datetime "live_at", precision: nil
    t.datetime "deleted_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["author_id"], name: "index_silent_posts_on_author_id"
    t.index ["deleted_at"], name: "index_silent_posts_on_deleted_at"
    t.index ["enabled"], name: "index_silent_posts_on_enabled"
    t.index ["live_at"], name: "index_silent_posts_on_live_at"
  end

  create_table "thing_with_compound_index_histories", force: :cascade do |t|
    t.integer "thing_with_compound_index_id", null: false
    t.string "key"
    t.string "value"
    t.datetime "history_started_at", precision: nil, null: false
    t.datetime "history_ended_at", precision: nil
    t.integer "history_user_id"
    t.index ["history_ended_at"], name: "index_thing_with_compound_index_histories_on_history_ended_at"
    t.index ["history_started_at"], name: "index_thing_with_compound_index_histories_on_history_started_at"
    t.index ["history_user_id"], name: "index_thing_with_compound_index_histories_on_history_user_id"
    t.index ["key", "value"], name: "idx_history_k_v"
    t.index ["thing_with_compound_index_id"], name: "idx_k_v_histories"
  end

  create_table "thing_with_compound_indices", force: :cascade do |t|
    t.string "key"
    t.string "value"
    t.index ["key", "value"], name: "idx_key_value"
  end

  create_table "thing_without_histories", force: :cascade do |t|
    t.string "name"
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
  end

end
