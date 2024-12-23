# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-
# stub: historiographer 4.0.0 ruby lib

require File.expand_path('lib/historiographer/version')
require "date"

Gem::Specification.new do |s|
  s.name = "historiographer".freeze
  s.version = Historiographer::VERSION

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["brettshollenberger".freeze]
  s.date = Date.today.strftime("%Y-%m-%d")
  s.description = "Append-only histories + chained snapshots of your ActiveRecord tables".freeze
  s.email = "brett.shollenberger@gmail.com".freeze
  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README.md"
  ]
  s.files = Dir.glob("{lib}/**/*", File::FNM_DOTMATCH).reject { |f| File.directory?(f) }
  s.homepage = "http://github.com/brettshollenberger/historiographer".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.2.22".freeze
  s.summary = "Create histories of your ActiveRecord tables".freeze

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_runtime_dependency(%q<activerecord>.freeze, [">= 6"])
    s.add_runtime_dependency(%q<activerecord-import>.freeze, [">= 0"])
    s.add_runtime_dependency(%q<activesupport>.freeze, [">= 0"])
    s.add_runtime_dependency(%q<rails>.freeze, [">= 6"])
    s.add_runtime_dependency(%q<rollbar>.freeze, [">= 0"])
    s.add_development_dependency(%q<mysql2>.freeze, ["= 0.5"])
    s.add_development_dependency(%q<paranoia>.freeze, [">= 0"])
    s.add_development_dependency(%q<pg>.freeze, [">= 0"])
    s.add_development_dependency(%q<pry>.freeze, [">= 0"])
    s.add_development_dependency(%q<standalone_migrations>.freeze, [">= 0"])
    s.add_development_dependency(%q<timecop>.freeze, [">= 0"])
    s.add_development_dependency(%q<bundler>.freeze, ["~> 1.0"])
    s.add_development_dependency(%q<jeweler>.freeze, [">= 0"])
    s.add_development_dependency(%q<rdoc>.freeze, ["~> 3.12"])
    s.add_development_dependency(%q<simplecov>.freeze, [">= 0"])
    s.add_development_dependency("zeitwerk")
  else
    s.add_dependency(%q<activerecord>.freeze, [">= 6"])
    s.add_dependency(%q<activerecord-import>.freeze, [">= 0"])
    s.add_dependency(%q<activesupport>.freeze, [">= 0"])
    s.add_dependency(%q<rails>.freeze, [">= 6"])
    s.add_dependency(%q<rollbar>.freeze, [">= 0"])
    s.add_dependency(%q<mysql2>.freeze, ["= 0.5"])
    s.add_dependency(%q<paranoia>.freeze, [">= 0"])
    s.add_dependency(%q<pg>.freeze, [">= 0"])
    s.add_dependency(%q<pry>.freeze, [">= 0"])
    s.add_dependency(%q<standalone_migrations>.freeze, [">= 0"])
    s.add_dependency(%q<timecop>.freeze, [">= 0"])
    s.add_dependency(%q<bundler>.freeze, ["~> 1.0"])
    s.add_dependency(%q<jeweler>.freeze, [">= 0"])
    s.add_dependency(%q<rdoc>.freeze, ["~> 3.12"])
    s.add_dependency(%q<simplecov>.freeze, [">= 0"])
    s.add_dependency("zeitwerk")
  end
end
