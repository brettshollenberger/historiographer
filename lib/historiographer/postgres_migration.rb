require_relative "history_migration"

if defined?(ActiveRecord::ConnectionAdapters::PostgreSQL::TableDefinition)
  class ActiveRecord::ConnectionAdapters::PostgreSQL::TableDefinition
    include Historiographer::HistoryMigration
  end
end
