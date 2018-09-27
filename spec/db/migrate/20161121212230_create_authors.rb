class CreateAuthors < ActiveRecord::Migration
  def change
    create_table :authors do |t|
      t.string :full_name, null: false
      t.text :bio
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :authors, :deleted_at
  end
end
