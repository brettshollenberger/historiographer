class CreateBylines < ActiveRecord::Migration[7.1]
  def change
    create_table :bylines do |t|
      t.string :name, null: false
      t.integer :author_id
      t.timestamps
    end
    
    add_index :bylines, :author_id
  end
end