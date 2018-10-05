require_relative "history_migration_mysql"

if defined?(ActiveRecord::ConnectionAdapters::Mysql2Adapter)
  class ActiveRecord::ConnectionAdapters::TableDefinition
    include Historiographer::HistoryMigrationMysql
  end
end
