source "https://rubygems.org"
ruby "2.6.3"

gem "activerecord", "~> 5.1"
gem "activesupport"
gem "rollbar"

group :development, :test do
  gem "pg"
  gem "pry"
  gem "mysql2", "0.4.10"
  gem "standalone_migrations"
  gem "timecop"
  gem "paranoia"
end

group :development do
  gem "rdoc", "~> 3.12"
  gem "bundler", "~> 1.0"
  gem "juwelier"
  gem "simplecov", ">= 0"
end

group :test do
  gem "rspec"
  gem "guard"
  gem "guard-rspec"
  gem "database_cleaner"
end
