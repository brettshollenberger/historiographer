# frozen_string_literal: true

require 'historiographer/postgres_migration'

class CreateSilentPostHistories < ActiveRecord::Migration[5.1]
  def change
    create_table :silent_post_histories, &:histories
  end
end
