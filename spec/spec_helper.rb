ENV["HISTORIOGRAPHER_ENV"] = "test"
ENV["RAILS_ENV"] = "test"

require_relative "../init.rb"
require "ostruct"
require "factory_bot"
require "zeitwerk"

# Add custom inflections for test environment
ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.acronym 'XGBoost'
  inflect.acronym 'ML'
  inflect.acronym 'EasyML'
end

# Set up autoloading
loader = Zeitwerk::Loader.new
loader.push_dir(File.join(File.dirname(__FILE__), 'models'))

# Configure Zeitwerk inflector with a custom inflection method
class CustomInflector < Zeitwerk::Inflector
  def camelize(basename, abspath)
    case basename
    when 'xgboost'
      'XGBoost'
    when 'xgboost_history'
      'XGBoostHistory'
    when /\Aeasy_ml\z/
      'EasyML'
    when /\Aml_model\z/
      'MLModel'
    else
      super
    end
  end
end

loader.inflector = CustomInflector.new
loader.setup

# Enable Rails-like constant lookup
module Rails
  def self.root
    Pathname.new(File.join(File.dirname(__FILE__), '..'))
  end

  def self.application
    OpenStruct.new(
      config: OpenStruct.new(
        eager_load_namespaces: [],
        autoloader: loader
      )
    )
  end
end

FactoryBot.definition_file_paths = %w{./factories ./spec/factories}
FactoryBot.find_definitions

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.filter_run :focus
  config.run_all_when_everything_filtered = true

  config.example_status_persistence_file_path = "spec/examples.txt"

  if config.files_to_run.one?
    config.default_formatter = 'doc'
  end

  config.profile_examples = 10

  config.order = :random

  Kernel.srand config.seed

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
    ActiveRecord::Migration.maintain_test_schema!
  end

  config.around(:each) do |example|
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.start
    example.run
    DatabaseCleaner.clean
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each, :logsql) do
    ActiveRecord::Base.logger = Logger.new(STDOUT)
  end

  config.after(:each, :logsql) do
    ActiveRecord::Base.logger = nil
  end
end
