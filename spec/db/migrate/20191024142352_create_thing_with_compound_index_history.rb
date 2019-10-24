require "historiographer/postgres_migration"
class CreateThingWithCompoundIndexHistory < ActiveRecord::Migration[5.2]
  def change
    create_table :thing_with_compound_index_histories do |t|
      t.histories index_names: {
        [:key, :value] => "idx_history_k_v",
        :thing_with_compound_index_id => "idx_k_v_histories"
      }
    end
  end
end
