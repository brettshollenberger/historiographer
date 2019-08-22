require "historiographer/postgres_migration"

class CreateSafePostHistories < ActiveRecord::Migration[5.1]
  def change
    create_table :safe_post_histories do |t|
      t.histories
    end
  end
end
