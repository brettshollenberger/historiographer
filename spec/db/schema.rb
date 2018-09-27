# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20171011194715) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "author_histories", force: :cascade do |t|
    t.integer  "author_id",          null: false
    t.string   "full_name",          null: false
    t.text     "bio"
    t.datetime "deleted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "history_started_at", null: false
    t.datetime "history_ended_at"
    t.integer  "history_user_id"
  end

  add_index "author_histories", ["author_id"], name: "index_author_histories_on_author_id", using: :btree
  add_index "author_histories", ["deleted_at"], name: "index_author_histories_on_deleted_at", using: :btree
  add_index "author_histories", ["history_ended_at"], name: "index_author_histories_on_history_ended_at", using: :btree
  add_index "author_histories", ["history_started_at"], name: "index_author_histories_on_history_started_at", using: :btree
  add_index "author_histories", ["history_user_id"], name: "index_author_histories_on_history_user_id", using: :btree

  create_table "authors", force: :cascade do |t|
    t.string   "full_name",  null: false
    t.text     "bio"
    t.datetime "deleted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "authors", ["deleted_at"], name: "index_authors_on_deleted_at", using: :btree

  create_table "ignorable_histories", force: :cascade do |t|
    t.integer  "ignorable_id",       null: false
    t.string   "name"
    t.string   "ignorable"
    t.datetime "history_started_at", null: false
    t.datetime "history_ended_at"
    t.integer  "history_user_id"
  end

  add_index "ignorable_histories", ["history_ended_at"], name: "index_ignorable_histories_on_history_ended_at", using: :btree
  add_index "ignorable_histories", ["history_started_at"], name: "index_ignorable_histories_on_history_started_at", using: :btree
  add_index "ignorable_histories", ["history_user_id"], name: "index_ignorable_histories_on_history_user_id", using: :btree
  add_index "ignorable_histories", ["ignorable_id"], name: "index_ignorable_histories_on_ignorable_id", using: :btree

  create_table "ignorables", force: :cascade do |t|
    t.string "name"
    t.string "ignorable"
  end

  create_table "post_histories", force: :cascade do |t|
    t.integer  "post_id",            null: false
    t.string   "title",              null: false
    t.text     "body",               null: false
    t.integer  "author_id",          null: false
    t.boolean  "enabled"
    t.datetime "live_at"
    t.datetime "deleted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "history_started_at", null: false
    t.datetime "history_ended_at"
    t.integer  "history_user_id"
  end

  add_index "post_histories", ["author_id"], name: "index_post_histories_on_author_id", using: :btree
  add_index "post_histories", ["deleted_at"], name: "index_post_histories_on_deleted_at", using: :btree
  add_index "post_histories", ["enabled"], name: "index_post_histories_on_enabled", using: :btree
  add_index "post_histories", ["history_ended_at"], name: "index_post_histories_on_history_ended_at", using: :btree
  add_index "post_histories", ["history_started_at"], name: "index_post_histories_on_history_started_at", using: :btree
  add_index "post_histories", ["history_user_id"], name: "index_post_histories_on_history_user_id", using: :btree
  add_index "post_histories", ["live_at"], name: "index_post_histories_on_live_at", using: :btree
  add_index "post_histories", ["post_id"], name: "index_post_histories_on_post_id", using: :btree

  create_table "posts", force: :cascade do |t|
    t.string   "title",                      null: false
    t.text     "body",                       null: false
    t.integer  "author_id",                  null: false
    t.boolean  "enabled",    default: false
    t.datetime "live_at"
    t.datetime "deleted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "posts", ["author_id"], name: "index_posts_on_author_id", using: :btree
  add_index "posts", ["deleted_at"], name: "index_posts_on_deleted_at", using: :btree
  add_index "posts", ["enabled"], name: "index_posts_on_enabled", using: :btree
  add_index "posts", ["live_at"], name: "index_posts_on_live_at", using: :btree

  create_table "safe_post_histories", force: :cascade do |t|
    t.integer  "safe_post_id",       null: false
    t.string   "title",              null: false
    t.text     "body",               null: false
    t.integer  "author_id",          null: false
    t.boolean  "enabled"
    t.datetime "live_at"
    t.datetime "deleted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "history_started_at", null: false
    t.datetime "history_ended_at"
    t.integer  "history_user_id"
  end

  add_index "safe_post_histories", ["author_id"], name: "index_safe_post_histories_on_author_id", using: :btree
  add_index "safe_post_histories", ["deleted_at"], name: "index_safe_post_histories_on_deleted_at", using: :btree
  add_index "safe_post_histories", ["enabled"], name: "index_safe_post_histories_on_enabled", using: :btree
  add_index "safe_post_histories", ["history_ended_at"], name: "index_safe_post_histories_on_history_ended_at", using: :btree
  add_index "safe_post_histories", ["history_started_at"], name: "index_safe_post_histories_on_history_started_at", using: :btree
  add_index "safe_post_histories", ["history_user_id"], name: "index_safe_post_histories_on_history_user_id", using: :btree
  add_index "safe_post_histories", ["live_at"], name: "index_safe_post_histories_on_live_at", using: :btree
  add_index "safe_post_histories", ["safe_post_id"], name: "index_safe_post_histories_on_safe_post_id", using: :btree

  create_table "safe_posts", force: :cascade do |t|
    t.string   "title",                      null: false
    t.text     "body",                       null: false
    t.integer  "author_id",                  null: false
    t.boolean  "enabled",    default: false
    t.datetime "live_at"
    t.datetime "deleted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "safe_posts", ["author_id"], name: "index_safe_posts_on_author_id", using: :btree
  add_index "safe_posts", ["deleted_at"], name: "index_safe_posts_on_deleted_at", using: :btree
  add_index "safe_posts", ["enabled"], name: "index_safe_posts_on_enabled", using: :btree
  add_index "safe_posts", ["live_at"], name: "index_safe_posts_on_live_at", using: :btree

  create_table "users", force: :cascade do |t|
    t.string "name"
  end

end
