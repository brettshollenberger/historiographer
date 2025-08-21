
require 'historiographer/postgres_migration'

class CreateProjectFiles < ActiveRecord::Migration[7.1]
  def change
    create_table :project_files do |t|
      t.bigint :project_id
      t.string :name, null: false
      t.string :content
      t.timestamps
      t.index :project_id
    end

    create_table :project_file_histories do |t|
      t.histories
    end
  end
end
