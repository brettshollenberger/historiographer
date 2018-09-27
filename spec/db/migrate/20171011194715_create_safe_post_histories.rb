require "historiographer/postgres_migration"

class CreateSafePostHistories < ActiveRecord::Migration
  def change
    create_table :safe_post_histories do |t|
      t.histories
    end
  end
end
