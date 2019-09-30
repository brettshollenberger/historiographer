require_relative "history_migration_mysql"

if defined?(ActiveRecord::ConnectionAdapters::Mysql2Adapter)
  class ActiveRecord::ConnectionAdapters::TableDefinition
    include Historiographer::HistoryMigrationMysql
  end
elsif defined?(ActiveRecord::ConnectionAdapters::TableDefinition)
  class ActiveRecord::ConnectionAdapters::TableDefinition
    include Historiographer::HistoryMigration
  end
end
