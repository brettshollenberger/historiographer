module Historiographer
  module HistoryMigrationMysql
    #
    # class CreateAdGroupHistories < ActiveRecord::Migration
    #  def change
    #    create_table :ad_group_histories do |t|
    #      t.histories
    #    end
    #  end
    # end
    #
    # t.histories(except: ["name"]) # don't include name column
    # t.histories(only: ["name"])   # only include name column
    # t.histories(no_business_columns: true) # only add history timestamps and history_user_id; manually add your own columns
    #
    # Will automatically add user_id, history_started_at,
    # and history_ended_at columns
    #
    def histories(except: [], only: [], no_business_columns: false, index_names: {})
      index_names.symbolize_keys!

      original_table_name = self.name.gsub(/_histories$/) { }.pluralize
      foreign_key = original_table_name.singularize.foreign_key

      class_definer = Class.new(ActiveRecord::Base) do
      end

      class_name = original_table_name.classify
      klass = Object.const_set(class_name, class_definer)
      original_columns = klass.columns.reject { |c| c.name == "id" || except.include?(c.name) || (only.any? && only.exclude?(c.name)) || no_business_columns }

      integer foreign_key.to_sym, null: false

      original_columns.each do |column|
        opts = {}
        opts.merge!(column.as_json.clone)

        send(column.type, column.name, opts.symbolize_keys!)
      end

      datetime :history_started_at, null: false
      datetime :history_ended_at
      integer :history_user_id

      index :history_started_at
      index :history_ended_at
      index :history_user_id
      index foreign_key

      ActiveRecord::Base.connection.indexes(original_table_name).each do |index|
        index index.columns
      end
    end
  end
end
