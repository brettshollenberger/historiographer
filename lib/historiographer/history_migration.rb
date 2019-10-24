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
    def histories(except: [], only: [], no_business_columns: false, index_names: {})
      index_names.symbolize_keys!
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

        send(column.type, column.name, opts.symbolize_keys!)
      end

      datetime :history_started_at, null: false
      datetime :history_ended_at
      integer :history_user_id

      indices_sql = %q(
        SELECT 
          DISTINCT(
            ARRAY_TO_STRING(ARRAY(
             SELECT pg_get_indexdef(idx.indexrelid, k + 1, true)
             FROM generate_subscripts(idx.indkey, 1) as k
             ORDER BY k
           ), ',')
         ) as indkey_names
        FROM pg_class t,
        pg_class i,
        pg_index idx,
        pg_attribute a,
        pg_am am
        WHERE t.oid = idx.indrelid
        AND i.oid = idx.indexrelid
        AND a.attrelid = t.oid
        AND a.attnum = ANY(idx.indkey)
        AND t.relkind = 'r'
        AND t.relname = ?;
      )

      indices_query_array = [indices_sql, original_table_name]
      indices_sanitized_query = klass.send(:sanitize_sql_array, indices_query_array)

      indexes = klass.connection.execute(indices_sanitized_query).to_a.map(&:values).flatten.reject { |i| i == "id" }.map { |i| i.split(",") }.concat([
        foreign_key,
        :history_started_at,
        :history_ended_at,
        :history_user_id
      ])

      indexes.each do |index_definition|
        index_definition = [index_definition].flatten.map(&:to_sym)
        index_name = index_definition.count == 1 ?  index_definition.first : index_definition

        if index_names.key?(index_name)
          index index_name, name: index_names[index_name]
        else
          index index_name
        end
      end

    end
  end
end