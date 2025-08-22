# encoding: utf-8

require 'rubygems'
require 'bundler'
require 'pry'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'
require 'jeweler'

Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://guides.rubygems.org/specification-reference/ for more options
  gem.name = "historiographer"
  gem.homepage = "http://github.com/brettshollenberger/historiographer"
  gem.license = "MIT"
  gem.summary = %Q{Create histories of your ActiveRecord tables}
  gem.description = %Q{Creates separate tables for each history table}
  gem.email = "brett.shollenberger@gmail.com"
  gem.authors = ["brettshollenberger"]
end
Jeweler::RubygemsDotOrgTasks.new

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'spec'
  test.pattern = 'rspec/**/*_spec.rb'
  test.verbose = true
end

desc "Code coverage detail"
task :simplecov do
  ENV['COVERAGE'] = "true"
  Rake::Task['test'].execute
end

task :default => :test

require 'rdoc/task'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "historiographer #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

require 'standalone_migrations'
StandaloneMigrations::Tasks.load_tasks

# Custom tasks for common operations
namespace :spec do
  require 'rspec/core/rake_task'
  
  desc "Run regular specs (excluding Rails integration)"
  RSpec::Core::RakeTask.new(:regular) do |t|
    t.rspec_opts = "--exclude-pattern spec/rails_integration/**/*_spec.rb"
  end
  
  desc "Run Rails integration specs with Combustion"
  RSpec::Core::RakeTask.new(:rails) do |t|
    t.pattern = "spec/rails_integration/**/*_spec.rb"
  end
  
  desc "Run all specs (regular and Rails integration separately)"
  task :all do
    puts "\n========== Running Regular Specs ==========\n"
    Rake::Task['spec:regular'].invoke
    puts "\n========== Running Rails Integration Specs ==========\n"
    Rake::Task['spec:rails'].invoke
  end
end

desc "Run regular test suite (default)"
task :spec => 'spec:regular'

desc "Setup test database"
task :test_setup do
  sh "bundle exec rake db:create"
  sh "bundle exec rake db:migrate"
end

desc "Reset test database"
task :test_reset do
  sh "bundle exec rake db:drop"
  sh "bundle exec rake db:create"
  sh "bundle exec rake db:migrate"
end

desc "Run linting and type checking"
task :lint do
  puts "No linting configured yet. Consider adding rubocop."
end

desc "Console with the gem loaded"
task :console do
  sh "bundle exec pry -r ./init.rb"
end

desc "List all available tasks"
task :help do
  sh "rake -T"
end
