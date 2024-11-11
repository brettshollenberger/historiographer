require 'historiographer/postgres_migration'

class CreateCommentHistories < ActiveRecord::Migration[7.1]
  def change
    create_table :comment_histories do |t|
      t.histories
    end
  end
end
