require "historiographer/postgres_migration"
require "historiographer/mysql_migration"

class CreateAuthorHistories < ActiveRecord::Migration[5.1]
  def change
    create_table :author_histories do |t|
      t.histories
    end
  end
end
