class CreateEasyMlColumns < ActiveRecord::Migration[7.0]
  def change
    create_table :easy_ml_columns do |t|
      t.string :name
      t.string :data_type
      t.timestamps
    end
    
    create_table :easy_ml_column_histories do |t|
      t.integer :easy_ml_column_id, null: false
      t.string :name
      t.string :data_type
      t.timestamps
      
      t.datetime :history_started_at, null: false
      t.datetime :history_ended_at
      t.integer :history_user_id
      t.string :snapshot_id
      
      t.index :easy_ml_column_id
      t.index :history_started_at
      t.index :history_ended_at
      t.index :snapshot_id
    end
  end
end