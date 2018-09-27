source "https://rubygems.org"
ruby "2.3.6"

gem "activerecord", "~> 4.0"
gem "activesupport"
gem "rollbar"

group :development, :test do
  gem "pg"
  gem "pry"
  gem "standalone_migrations"
  gem "timecop"
  gem "paranoia", "~> 2.2"
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
