# Single Table Inheritance (STI) Implementation for Historiographer

You are assisting with a Rails gem called Historiographer. Your role is to make precise, surgical edits to the codebase based on specific tasks. The project has a complex architecture with interdependent components, so caution is required.

## Overview

This document outlines the steps needed to properly implement Single Table Inheritance (STI) for the Historiographer gem, following Rails best practices. The current implementation has a complex method forwarding mechanism that can lead to subtle bugs. We need to refactor this to use a clean, standard Rails STI approach within separate inheritance hierarchies.

## Current State Analysis

The current implementation has the following issues:

1. History classes implement a complex method delegation approach using `method_missing` and dynamic method definition
2. STI is partially implemented but doesn't correctly handle the inheritance hierarchy within history classes
3. The `type` column isn't properly set or managed according to Rails STI conventions
4. Method delegation between original and history models is overly complex and error-prone

## Implementation Requirements

1. User can define a `type` for their class, and that will be used to identify the STI class
2. The `type` should be a string, and the default value should be the class name
3. When a user creates a new instance, the `type` should be set to the class name automatically
4. STI subclasses should automatically inherit from their parent class
5. History classes should maintain a parallel inheritance hierarchy to original classes
6. When finding a history instance, it should automatically instantiate the correct subclass based on `type`
7. Implement clean method delegation from history classes to original models

## Implementation Approach: STI Within History Models

We will implement STI separately within original models and history models, maintaining two parallel inheritance hierarchies:

1. **Original Models Hierarchy**: `PrivatePost < Post < ActiveRecord::Base`
2. **History Models Hierarchy**: `PrivatePostHistory < PostHistory < ActiveRecord::Base`

This approach follows Rails conventions within each table while providing a clean way to implement method delegation between related models.

## Implementation Steps

### 1. Update `Historiographer::History` Module

#### Changes Required:

- Implement a clean method delegation system using `method_missing`
- Support proper STI inheritance within history models
- Ensure history classes correctly set and manage their `type` column
- Maintain table separation between original and history models

```ruby
module Historiographer
  module History
    extend ActiveSupport::Concern

    included do |base|
      clear_validators! if respond_to?(:clear_validators!)

      # Current scope for finding the most recent history
      scope :current, -> { where(history_ended_at: nil).order(id: :desc) }

      # Determine original class name
      cattr_accessor :original_class_name
      self.original_class_name = base.name.gsub(/History$/, '')

      # Setup inheritance column for history classes
      if self.original_class_name.constantize.respond_to?(:inheritance_column)
        original_inheritance_column = self.original_class_name.constantize.inheritance_column
        self.inheritance_column = original_inheritance_column
      end

      # Set up user association
      unless self.original_class_name.constantize.ancestors.include?(Historiographer::Silent)
        belongs_to :user, foreign_key: :history_user_id
      end

      # Ensure we can't destroy history records
      before_destroy { |record| raise "Cannot destroy history records" }

      # Handle type column for history classes
      after_initialize do
        # Set type to the history class if not already set
        if self.type.nil? || !self.type.ends_with?('History')
          self.type = self.class.name
        end
      end

      # Setup class accessors for delegation
      cattr_accessor :delegated_methods
      self.delegated_methods = []
    end

    # Method delegation system
    def method_missing(method, *args, &block)
      # Try to find the original record to delegate to
      foreign_key = self.class.determine_foreign_key
      original_record = self.class.original_class_name.constantize.find_by(id: send(foreign_key))

      if original_record && original_record.respond_to?(method)
        # Cache the method for future calls
        self.class.delegate_method(method)
        # Call the method on the original record
        original_record.send(method, *args, &block)
      else
        super
      end
    end

    def respond_to_missing?(method, include_private = false)
      # Check if the original class responds to this method
      foreign_key = self.class.determine_foreign_key
      original_record = self.class.original_class_name.constantize.find_by(id: send(foreign_key))
      original_record&.respond_to?(method, include_private) || super
    end

    class_methods do
      # Method to delegate methods from original class
      def delegate_method(method_name)
        return if method_defined?(method_name) || delegated_methods.include?(method_name.to_sym)

        delegated_methods << method_name.to_sym

        define_method(method_name) do |*args, &block|
          foreign_key = self.class.determine_foreign_key
          original_record = self.class.original_class_name.constantize.find_by(id: send(foreign_key))

          if original_record
            original_record.send(method_name, *args, &block)
          else
            raise NoMethodError, "undefined method `#{method_name}' for #{self}"
          end
        end
      end

      # Determine the foreign key based on the original class
      def determine_foreign_key
        association_name = self.original_class_name.split("::").last.underscore
        "#{association_name}_id"
      end
    end

    # Prevent destroying history records
    def destroy
      false
    end

    def destroy!
      false
    end

    # Other existing scopes and methods...
  end
end
```

### 2. Update Original Model STI Support in `Historiographer` Module

#### Changes Required:

- Ensure proper type column handling in original models
- Support proper mapping between original and history class hierarchy
- Handle custom inheritance columns

```ruby
module Historiographer
  extend ActiveSupport::Concern

  included do |base|
    # Existing code...

    # Set default type for original models
    if base.respond_to?(:inheritance_column) && base.column_names.include?(base.inheritance_column)
      before_validation do
        self[self.class.inheritance_column] ||= self.class.name
      end
    end

    # Ensure history class creation supports STI
    class_name = "#{base.name}History"

    begin
      history_class = class_name.constantize
    rescue NameError
      # Get the base table name without _histories suffix
      base_table = base.table_name.singularize.sub(/_histories$/, '')

      # Find the correct parent history class for STI
      if base.superclass != ActiveRecord::Base && base.superclass.include?(Historiographer)
        parent_history_class_name = "#{base.superclass.name}History"
        begin
          parent_history_class = parent_history_class_name.constantize
        rescue NameError
          parent_history_class = ActiveRecord::Base
        end
      else
        parent_history_class = ActiveRecord::Base
      end

      # Create history class with proper inheritance
      history_class_initializer = Class.new(parent_history_class) do
        self.table_name = "#{base_table}_histories"
        include Historiographer::History

        # Set original class name for delegation
        self.original_class_name = base.name

        # Handle inheritance column
        if base.respond_to?(:inheritance_column)
          self.inheritance_column = base.inheritance_column
        end
      end

      # Register the new class in the proper namespace
      module_parts = class_name.split('::')
      final_class_name = module_parts.pop

      # Find or create module nesting
      parent_module = Object
      module_parts.each do |part|
        parent_module = if parent_module.const_defined?(part)
                        parent_module.const_get(part)
                      else
                        parent_module.const_set(part, Module.new)
                      end
      end

      # Define the history class
      history_class = parent_module.const_set(final_class_name, history_class_initializer)
    end

    # Existing code...
  end

  # Add helper methods for STI
  module ClassMethods
    def history_class_for_type(type_value)
      if type_value.present?
        "#{type_value}History".constantize
      else
        "#{self.name}History".constantize
      end
    rescue NameError
      history_class
    end
  end

  # Instance methods related to history and STI
  def create_history(snapshot_id: nil)
    # Use the correct history class based on the current type
    type_column = self.class.inheritance_column
    current_type = self[type_column] || self.class.name

    begin
      specific_history_class = self.class.history_class_for_type(current_type)
    rescue NameError
      specific_history_class = self.class.history_class
    end

    # Create history record with the proper type
    history_record = record_history(specific_history_class, snapshot_id: snapshot_id)
    history_record
  end
end
```

## Migration Testing Requirements

1. Create comprehensive test cases for STI behavior in original and history models
2. Test inheritance between original models (e.g., `PrivatePost < Post`)
3. Test inheritance between history models (e.g., `PrivatePostHistory < PostHistory`)
4. Test method delegation from history models to original models
5. Test custom inheritance columns
6. Test namespaced models
7. Verify proper handling of the `type` column in both original and history tables

## Backward Compatibility

To ensure backward compatibility:

1. Maintain existing history table structures
2. Ensure old history records continue to work with the new implementation
3. Support the same public API for accessing history records
4. Handle existing applications that may have customized history class behavior

By implementing STI separately within original and history models, we maintain Rails conventions while providing clean method delegation between related models.
