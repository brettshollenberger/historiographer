require "historiographer/postgres_migration"
require "historiographer/mysql_migration"

class CreatePostHistories < ActiveRecord::Migration[5.1]
  def change
    create_table :post_histories do |t|
      t.histories
    end
  end
end
