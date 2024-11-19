class AddTypeToPosts < ActiveRecord::Migration[7.1]
  def change
    add_column :posts, :type, :string
    add_index :posts, :type
  end
end
