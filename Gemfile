# frozen_string_literal: true

source 'https://rubygems.org'
ruby '3.0.2'

gem 'activerecord', '>= 6'
gem 'activerecord-import'
gem 'activesupport'
gem 'rails', '>= 6'
gem 'rollbar'

group :development, :test do
  gem 'mysql2', '0.5'
  gem 'paranoia'
  gem 'pg'
  gem 'pry'
  gem 'standalone_migrations'
  gem 'timecop'
end

group :development do
  gem 'bundler', '~> 1.0'
  gem 'jeweler', git: 'https://github.com/technicalpickles/jeweler', branch: 'master'
  gem 'rdoc', '~> 3.12'
  gem 'simplecov', '>= 0'
end

group :test do
  gem 'database_cleaner'
  gem 'factory_bot_rails'
  gem 'guard'
  gem 'guard-rspec'
  gem 'rspec'
end
