# frozen_string_literal: true

ENV['RAILS_ENV'] ||= 'test'

require 'bundler'
Bundler.require :default, :test

require 'historiographer'
require 'combustion'

Combustion.path = 'spec/internal'
Combustion.initialize! :active_record do
  config.load_defaults Rails::VERSION::STRING.to_f
end

require 'rspec/rails'
require 'database_cleaner'

RSpec.configure do |config|
  config.use_transactional_fixtures = false
  
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end
  
  config.before(:each) do
    DatabaseCleaner.start
  end
  
  config.after(:each) do
    DatabaseCleaner.clean
  end
end