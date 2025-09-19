require 'historiographer/history_migration'

class CreateWebsiteHistories < ActiveRecord::Migration[7.0]
  def change
    create_table :website_histories do |t|
      t.histories
    end
  end
end