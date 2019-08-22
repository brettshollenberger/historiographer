require "historiographer/postgres_migration"

class CreateUsers < ActiveRecord::Migration[5.1]
  def change
    create_table :users do |t|
      t.string :name
    end
  end
end
