class CreateWebsites < ActiveRecord::Migration[7.0]
  def change
    create_table :websites do |t|
      t.string :domain, null: false
      t.references :template, foreign_key: true
      t.timestamps
    end
  end
end