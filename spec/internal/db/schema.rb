# frozen_string_literal: true

ActiveRecord::Schema.define(version: 1) do
  # Website table - the main model
  create_table :websites, force: true do |t|
    t.string :name
    t.integer :project_id
    t.integer :user_id
    t.integer :template_id
    t.timestamps
  end

  # Website history table
  create_table :website_histories, force: true do |t|
    t.integer :website_id, null: false
    t.string :name
    t.integer :project_id  
    t.integer :user_id
    t.integer :template_id
    t.datetime :created_at, null: false
    t.datetime :updated_at, null: false
    t.datetime :history_started_at, null: false
    t.datetime :history_ended_at
    t.integer :history_user_id
    t.string :snapshot_id
    t.string :thread_id
  end

  add_index :website_histories, :website_id
  add_index :website_histories, :history_started_at
  add_index :website_histories, :history_ended_at
  add_index :website_histories, :history_user_id
  add_index :website_histories, :snapshot_id
  add_index :website_histories, [:thread_id], unique: true, name: 'index_website_histories_on_thread_id'

  # Deploy table - to test associations on history models
  create_table :deploys, force: true do |t|
    t.integer :website_history_id
    t.string :status
    t.timestamps
  end

  # User table
  create_table :users, force: true do |t|
    t.string :name
    t.timestamps
  end
end