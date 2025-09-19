require 'historiographer/history_migration'

class CreateTemplateHistories < ActiveRecord::Migration[7.0]
  def change
    create_table :template_histories do |t|
      t.histories
    end
  end
end