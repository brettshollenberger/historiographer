require_relative "history_migration"

if defined?(ActiveRecord::ConnectionAdapters::PostgreSQL::TableDefinition)
  class ActiveRecord::ConnectionAdapters::PostgreSQL::TableDefinition
    include Historiographer::HistoryMigration
  end
elsif defined?(ActiveRecord::ConnectionAdapters::TableDefinition)
  class ActiveRecord::ConnectionAdapters::TableDefinition
    include Historiographer::HistoryMigration
  end
end
