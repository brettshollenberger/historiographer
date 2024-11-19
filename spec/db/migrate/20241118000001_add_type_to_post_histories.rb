class AddTypeToPostHistories < ActiveRecord::Migration[7.0]
  def change
    add_column :post_histories, :type, :string
  end
end
