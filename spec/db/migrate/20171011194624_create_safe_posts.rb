class CreateSafePosts < ActiveRecord::Migration
  def change
    create_table :safe_posts do |t|
      t.string :title, null: false
      t.text :body, null: false
      t.integer :author_id, null: false
      t.boolean :enabled, default: false
      t.datetime :live_at
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :safe_posts, :author_id
    add_index :safe_posts, :enabled
    add_index :safe_posts, :live_at
    add_index :safe_posts, :deleted_at
  end
end
