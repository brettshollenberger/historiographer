require 'historiographer/postgres_migration'

class CreateProjects < ActiveRecord::Migration[7.1]
  def change
    create_table :projects do |t|
      t.string :name, null: false
      t.timestamps
    end

    create_table :project_histories do |t|
      t.histories
    end
  end
end
