require "historiographer/postgres_migration"
require "historiographer/mysql_migration"

class CreateMlModels < ActiveRecord::Migration[7.0]
  def change
    create_table :ml_models do |t|
      t.string :name
      t.string :model_type
      t.jsonb :parameters
      t.timestamps

      t.index :model_type
    end

    create_table :ml_model_histories do |t|
      t.histories
    end
  end
end
