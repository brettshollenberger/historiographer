class CreateThingWithCompoundIndex < ActiveRecord::Migration[5.2]
  def change
    create_table :thing_with_compound_indices do |t|
      t.string :key
      t.string :value

      t.index [:key, :value], name: "idx_key_value"
    end
  end
end
