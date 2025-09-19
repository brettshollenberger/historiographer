require 'historiographer/history_migration'

class CreateTemplateFileHistories < ActiveRecord::Migration[7.0]
  def change
    create_table :template_file_histories do |t|
      t.histories
    end
  end
end