module Historiographer
  module HistoryMigration
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
    def histories(except: [], only: [], no_business_columns: false)
      original_table_name = self.name.gsub(/_histories$/) {}.pluralize
      foreign_key         = original_table_name.singularize.foreign_key

      class_definer = Class.new(ActiveRecord::Base) do
      end

      class_name = original_table_name.classify
      klass      = Object.const_set(class_name, class_definer)
      original_columns = klass.columns.reject { |c| c.name == "id" || except.include?(c.name) || (only.any? && only.exclude?(c.name)) || no_business_columns }

      integer foreign_key.to_sym, null: false

      original_columns.each do |column|
        opts = {}
        opts.merge!(column.as_json.clone)
        # opts.merge!(column.type.as_json.clone)

        send(column.type, column.name, opts.symbolize_keys!)
      end

      datetime :history_started_at, null: false
      datetime :history_ended_at
      integer :history_user_id

      index :history_started_at
      index :history_ended_at
      index :history_user_id
      index foreign_key

      indices_sql = <<-SQL
        SELECT
            a.attname AS column_name
        FROM
            pg_class t,
            pg_class i,
            pg_index ix,
            pg_attribute a
        WHERE
            t.oid = ix.indrelid
            AND i.oid = ix.indexrelid
            AND a.attrelid = t.oid
            AND a.attnum = ANY(ix.indkey)
            AND t.relkind = 'r'
            AND t.relname = ?
        ORDER BY
            t.relname,
            i.relname;
      SQL

      indices_query_array = [indices_sql, original_table_name]
      indices_sanitized_query = klass.send(:sanitize_sql_array, indices_query_array)

      klass.connection.execute(indices_sanitized_query).to_a.map(&:values).flatten.reject { |i| i == "id" }.each do |index_name|
        index index_name.to_sym
      end

    end
  end
end
