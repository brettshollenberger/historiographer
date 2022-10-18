# frozen_string_literal: true

class CreateSilentPosts < ActiveRecord::Migration[5.1]
  def change
    create_table :silent_posts do |t|
      t.string :title, null: false
      t.text :body, null: false
      t.integer :author_id, null: false
      t.boolean :enabled, default: false
      t.datetime :live_at
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :silent_posts, :author_id
    add_index :silent_posts, :enabled
    add_index :silent_posts, :live_at
    add_index :silent_posts, :deleted_at
  end
end
