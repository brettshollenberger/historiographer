require "historiographer/postgres_migration"
require "historiographer/mysql_migration"

class CreateEasyMlColumns < ActiveRecord::Migration[7.1]
  def change
    create_table :easy_ml_columns do |t|
      t.string :name, null: false
      t.string :data_type, null: false
      t.string :column_type
      t.timestamps
    end

    create_table :easy_ml_column_histories do |t|
      t.histories
    end
  end
end
