# Historiographer Development Guide

## Quick Start

```bash
# Initial setup
bin/setup

# Run tests
bin/test        # Regular test suite (fast)
bin/test-rails  # Rails integration tests (slower)
bin/test-all    # Both test suites

# Interactive console
bin/console
```

## Available Commands

### Using Rake Tasks

```bash
# Testing
rake spec           # Run regular specs (default)
rake spec:regular   # Run regular specs explicitly
rake spec:rails     # Run Rails integration specs
rake spec:all       # Run all specs

# Database
rake db:create      # Create test database
rake db:migrate     # Run migrations
rake db:rollback    # Rollback migrations
rake test_setup     # Setup test database
rake test_reset     # Reset test database

# Other
rake console        # Launch console with gem loaded
rake help           # List all available tasks
```

### Using Bin Scripts

All scripts are in the `bin/` directory:

- `bin/setup` - Initial development setup
- `bin/test` - Run regular test suite
- `bin/test-rails` - Run Rails integration tests  
- `bin/test-all` - Run all tests
- `bin/console` - Interactive console

### Direct Commands

```bash
# Run specific tests
bundle exec rspec spec/historiographer_spec.rb
bundle exec rspec spec/historiographer_spec.rb:100  # Run specific line

# Rails integration tests only
bundle exec rspec spec/rails_integration

# Database operations
bundle exec rake db:create
bundle exec rake db:migrate
bundle exec rake db:rollback
```

## Test Organization

The test suite is split into two parts:

1. **Regular Tests** (`spec/*.rb`, `spec/models/*.rb`, etc.)
   - Fast, lightweight Rails simulation
   - Uses standalone_migrations
   - Default when running `rake spec` or `bin/test`

2. **Rails Integration Tests** (`spec/rails_integration/*.rb`)
   - Uses Combustion to create a real Rails app
   - Tests Rails-specific behaviors like autoloading
   - Run separately with `rake spec:rails` or `bin/test-rails`

## Database Setup

The gem uses PostgreSQL for testing. Two databases are used:

1. `historiographer_test` - Main test database
2. `historiographer_combustion_test` - Rails integration test database

Configure database connection in:
- `spec/db/database.yml` - Main test database
- `spec/internal/config/database.yml` - Combustion test database

## Adding New Tests

### Regular Tests
Place in `spec/` directory. Models go in `spec/models/`.

### Rails Integration Tests  
Place in `spec/rails_integration/`. These tests use Combustion and require:
```ruby
require 'combustion_helper'
```

## Debugging

```bash
# Launch console with all models loaded
bin/console

# Or with rake
rake console

# Or manually
bundle exec pry -r ./init.rb
```

## Gem Development

```bash
# Build gem
rake build

# Release new version
rake release
```