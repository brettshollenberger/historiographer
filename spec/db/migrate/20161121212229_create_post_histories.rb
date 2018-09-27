require "historiographer/postgres_migration"

class CreatePostHistories < ActiveRecord::Migration
  def change
    create_table :post_histories do |t|
      t.histories
    end
  end
end
