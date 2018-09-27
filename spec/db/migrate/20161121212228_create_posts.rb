class CreatePosts < ActiveRecord::Migration
  def change
    create_table :posts do |t|
      t.string :title, null: false
      t.text :body, null: false
      t.integer :author_id, null: false
      t.boolean :enabled, default: false
      t.datetime :live_at
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :posts, :author_id
    add_index :posts, :enabled
    add_index :posts, :live_at
    add_index :posts, :deleted_at
  end
end
