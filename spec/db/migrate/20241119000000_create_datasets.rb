require 'historiographer/postgres_migration'

class CreateDatasets < ActiveRecord::Migration[7.1]
  def change
    create_table :datasets do |t|
      t.string :name, null: false
      t.bigint :ml_model_id
      t.timestamps

      t.index :ml_model_id
    end

    create_table :dataset_histories do |t|
      t.histories
    end
  end
end
