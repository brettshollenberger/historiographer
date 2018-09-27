require "yaml"

Bundler.require(:default, :development, :test)

Dir.glob(File.expand_path("lib/**/*.rb")).each do |file|
  require file
end

database_config = YAML.load(File.open(File.expand_path("spec/db/database.yml")).read)

env = ENV["HISTORIOGRAPHER_ENV"] || "development"

db_env_config = database_config[env]

if defined?(ActiveRecord::Base)
  # new settings as specified here: https://devcenter.heroku.com/articles/concurrency-and-database-connections
  ActiveRecord::Base.establish_connection(db_env_config)
end
