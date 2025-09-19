class CreateWebsiteFiles < ActiveRecord::Migration[7.0]
  def change
    create_table :website_files do |t|
      t.references :website, foreign_key: true, null: false
      t.string :path, null: false
      t.text :content
      t.tsvector :content_tsv
      t.string :shasum
      t.integer :file_specification_id
      t.timestamps
    end

    add_index :website_files, [:website_id, :path], unique: true
  end
end