class CreateThingWithoutHistory < ActiveRecord::Migration[5.2]
  def change
    create_table :thing_without_histories do |t|
      t.string :name
    end
  end
end
