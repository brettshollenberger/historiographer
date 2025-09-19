require 'historiographer/history_migration'

class CreateWebsiteFileHistories < ActiveRecord::Migration[7.0]
  def change
    create_table :website_file_histories do |t|
      t.histories
    end
  end
end