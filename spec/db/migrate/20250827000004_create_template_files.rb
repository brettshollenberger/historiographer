class CreateTemplateFiles < ActiveRecord::Migration[7.0]
  def change
    create_table :template_files do |t|
      t.references :template, foreign_key: true, null: false
      t.string :path, null: false
      t.text :content
      t.tsvector :content_tsv
      t.string :shasum
      t.integer :file_specification_id
      t.timestamps
    end

    add_index :template_files, [:template_id, :path], unique: true
  end
end