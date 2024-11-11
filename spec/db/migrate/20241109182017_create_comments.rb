class CreateComments < ActiveRecord::Migration[7.1]
  def change
    create_table :comments do |t|
      t.bigint :post_id
      t.bigint :author_id
      t.text :body
      t.timestamps

      t.index :post_id
      t.index :author_id
    end
  end
end
