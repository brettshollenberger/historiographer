require 'active_support/concern'

#
# See Historiographer for more details
#
# Historiographer::History is a mixin that is
# automatically included in any History class (e.g. RetailerProductHistory).
#
# A History record represents a snapshot of a primary record at a particular point
# in time.
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# E.g. You have a RetailerProduct (ID: 1) that makes the following changes:
#
# 1) rp = RetailerProduct.create(name: "Sabra")
#
# 2) rp.update(name: "Sabra Hummus")
#
# 3) rp.update(name: "Sabra Pine Nut Hummus")
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# Your RetailerProduct record looks like this:
#
# <#RetailerProduct:0x007fbf00c78f00 name: "Sabra Pine Nut Hummus">
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# But your RetailerProductHistories look like this:
#
# rp.histories
#
# <#RetailerProductHistory:0x007fbf00c78f01 name: "Sabra", history_started_at: 1.minute.ago, history_ended_at: 30.seconds.ago>
# <#RetailerProductHistory:0x007fbf00c78f02 name: "Sabra Hummus", history_started_at: 30.seconds.ago, history_ended_at: 10.seconds.ago>
# <#RetailerProductHistory:0x007fbf00c78f03 name: "Sabra Pine Nut Hummus", history_started_at: 10.seconds.ago, history_ended_at: nil>
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# Since these Histories are intended to represent a snapshot in time, they should never be
# deleted or modified directly. Historiographer will manage all of the nuances for you.
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# Your classes should be written like this:
#
# class RetailerProduct < ActiveRecord::Base
#   include Historiographer
# end
#
# # This class is created automatically. You don't
# # need to create a file yourself, unless you
# # want to add additional methods.
# #
# class RetailerProductHistory < ActiveRecord::Base
#   include Historiographer::History
# end
#
module Historiographer
  module History
    extend ActiveSupport::Concern

    included do |base|
      clear_validators! if respond_to?(:clear_validators!)
      #
      # A History class (e.g. RetailerProductHistory) will gain
      # access to a current scope, returning
      # the most recent history.
      #
      scope :current, -> { where(history_ended_at: nil).order(id: :desc) }


      # 
      # Historiographer is opinionated about how History classes
      # should be named.
      #
      # For a class named "RetailerProductHistory", the History class should be named
      # "RetailerProductHistory."
      #
      foreign_class_name = base.name.gsub(/History$/) {}        # e.g. "RetailerProductHistory" => "RetailerProduct"
      association_name   = foreign_class_name.split("::").last.underscore.to_sym # e.g. "RetailerProduct" => :retailer_product

      # Defer foreign class resolution to avoid load order issues
      base.define_singleton_method :foreign_class do
        return class_variable_get(:@@foreign_class) if class_variable_defined?(:@@foreign_class)
        begin
          foreign_class = foreign_class_name.constantize
          class_variable_set(:@@foreign_class, foreign_class)
          foreign_class
        rescue NameError => e
          # If the class isn't loaded yet, return nil and it will be retried later
          nil
        end
      end

      # Store the foreign class name for later use
      class_variable_set(:@@foreign_class_name, foreign_class_name)
      class_variable_set(:@@association_name, association_name)

      #
      # A History class will be linked to the user
      # that made the changes.
      #
      # E.g.
      #
      # RetailerProductHistory.first.user
      #
      # To use histories, a user class must be defined.
      #
      # Set up user association unless Silent module is included
      # Defer this check until foreign_class is available
      unless base.foreign_class && base.foreign_class.ancestors.include?(Historiographer::Silent)
        belongs_to :user, foreign_key: :history_user_id
      end

      # Add method_added hook to the original class when it's available
      # This needs to be deferred until the foreign class is loaded
      base.define_singleton_method :setup_method_delegation do
        return unless foreign_class
        return if class_variable_defined?(:@@method_delegation_setup) && class_variable_get(:@@method_delegation_setup)
        class_variable_set(:@@method_delegation_setup, true)
        
        foreign_class.singleton_class.class_eval do
        # Keep track of original method_added if it exists
        if method_defined?(:method_added)
          alias_method :original_method_added, :method_added
        end

        define_method(:method_added) do |method_name|
          # Skip if we're already in the process of defining a method
          return if Thread.current[:defining_historiographer_method]

          begin
            Thread.current[:defining_historiographer_method] = true
            
            # Call original method_added if it exists
            original_method_added(method_name) if respond_to?(:original_method_added)

            # Get the method object to check if it's from our class (not inherited)
            method_obj = instance_method(method_name)
            return unless method_obj.owner == self

            # Skip if we've already defined this method in the history class
            return if self.history_class.method_defined?(method_name)

            self.history_class.class_eval do
              define_method(method_name) do |*args, **kwargs, &block|
                forward_method(method_name, *args, **kwargs, &block)
              end
            end
          ensure
            Thread.current[:defining_historiographer_method] = false
          end
        end
      end

      begin
        end
      end
      
      # Try to set up method delegation if foreign class is available
      base.setup_method_delegation if base.foreign_class
      
      # Also delegate existing methods from the foreign class
      if base.foreign_class
        begin
          (base.foreign_class.columns.map(&:name) - ["id"]).each do |method_name|
            define_method(method_name) do |*args, **kwargs, &block|
              forward_method(method_name, *args, **kwargs, &block)
            end
          end
        rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished
          # Table might not exist yet during setup
        end
      end

      # Add method_missing for any methods we might have missed
      def method_missing(method_name, *args, **kwargs, &block)
        original_class = self.class.foreign_class
        if original_class && original_class.method_defined?(method_name)
          forward_method(method_name, *args, **kwargs, &block)
        else
          super
        end
      end

      def respond_to_missing?(method_name, include_private = false)
        original_class = self.class.foreign_class
        (original_class && original_class.method_defined?(method_name)) || super
      end

      #
      # Historiographer will automatically setup the association
      # to the primary class (e.g. RetailerProduct)
      #
      # If the History class has already defined this association, raise
      # an error, because we don't yet see any reason why end users
      # should be allowed to override this method.
      #
      # At some point, we may decide to allow this, but for now, we don't
      # know what the requirements/use cases would be.
      #
      # e.g.
      #
      # if RetailerProductHistory.respond_to?(:retailer_product)
      #   raise "RetailerProductHistory already has #retailer_product association. Talk to Brett if this is a legit use case"
      # else
      #   belongs_to :retailer_product, class_name: RetailerProduct
      # end
      #
      if base.respond_to?(association_name)
        raise "#{base} already has ##{association_name} association. Talk to Brett if this is a legit use case."
      else
        belongs_to association_name, class_name: foreign_class_name
      end

      # Ensure we can't destroy history records
      before_destroy { |record| raise "Cannot destroy history records" }

      #
      # A History record should never be destroyed.
      #
      # History records are immutable, so we enforce
      # this constraint as much as we can at the Rails layer.
      #
      def destroy
        false
      end

      def destroy!
        false
      end

      #
      # History records should never be updated, except to set
      # history_ended_at (when they are overridden by future histories).
      #
      # If the record was already persisted, then they only change it
      # is allowed to make is to history_ended_at.
      #
      # If the record was not already persisted, proceed as normal.
      #
      def save(*args, **kwargs)
        if persisted? && (changes.keys - %w(history_ended_at snapshot_id)).any?
          false
        else
          super(*args, **kwargs)
        end
      end

      def save!(*args, **kwargs)
        if persisted? && (changes.keys - %w(history_ended_at snapshot_id)).any?
          false
        else
          super(*args, **kwargs)
        end
      end

      # Returns the most recent snapshot for each snapshot_id
      # Orders by history_started_at and id to handle cases where multiple records
      # have the same history_started_at timestamp
      scope :latest_snapshot, -> {
        where.not(snapshot_id: nil)
          .select('DISTINCT ON (snapshot_id) *')
          .order('snapshot_id, history_started_at DESC, id DESC')
      }

      # Track custom association methods
      base.class_variable_set(:@@history_association_methods, [])
      
      # Register this history class to have its associations set up after initialization
      history_classes = Thread.current[:historiographer_history_classes] ||= []
      history_classes << base
      
      # Always define the setup_history_associations method
      base.define_singleton_method :setup_history_associations do |force = false|
        return if !force && class_variable_defined?(:@@associations_set_up) && class_variable_get(:@@associations_set_up)
        class_variable_set(:@@associations_set_up, true)
        
        return unless foreign_class
        
        # Also set up method delegation if not already done
        setup_method_delegation if respond_to?(:setup_method_delegation)
        
        foreign_class.reflect_on_all_associations.each do |association|
          begin
            define_history_association(association)
          rescue => e
            # Log but don't fail
            puts "Warning: Could not define history association #{association.name}: #{e.message}" if ENV['DEBUG']
          end
        end
      end
      
      # Set up the after_initialize hook if we're in a Rails app
      if defined?(Rails) && Rails.respond_to?(:application) && Rails.application && Rails.application.config.respond_to?(:after_initialize)
        Rails.application.config.after_initialize do
          history_classes.each do |history_class|
            history_class.setup_method_delegation if history_class.respond_to?(:setup_method_delegation)
            history_class.setup_history_associations
          end
        end
      else
        # For non-Rails environments, try to set up associations immediately
        
        # Try to set up now if possible
        begin
          base.setup_history_associations
        rescue => e
          # Will retry later
        end
        
        # Override reflect_on_association to ensure associations are defined
        base.define_singleton_method :reflect_on_association do |name|
          setup_history_associations rescue nil
          super(name)
        end
        
        # Override reflect_on_all_associations to ensure associations are defined
        base.define_singleton_method :reflect_on_all_associations do |*args|
          setup_history_associations rescue nil
          super(*args)
        end
      end

      def snapshot
        raise "Cannot snapshot a history model!"
      end

      def is_history_class?
        true
      end

    end

    class_methods do
      def is_history_class?
        true
      end

      def original_class
        # Use the foreign_class method we defined earlier
        foreign_class
      end

      def define_history_association(association)
        if association.is_a?(Symbol) || association.is_a?(String)
          association = original_class.reflect_on_association(association)
          # If the association doesn't exist on the original class, skip it
          return unless association
        end
        
        assoc_name = association.name
        assoc_foreign_key = association.foreign_key

        # Skip through associations to history classes to avoid infinite loops
        return if association.class_name.end_with?('History')

        # Get the associated model's table name
        original_assoc_class = association.class_name.safe_constantize
        return unless original_assoc_class  # Can't proceed without the class
        
        assoc_table_name = original_assoc_class.table_name
        history_table_name = "#{assoc_table_name.singularize}_histories"
        
        # Check if a history table exists for this association
        has_history_table = ActiveRecord::Base.connection.tables.include?(history_table_name)
        
        if has_history_table
          # This model has history tracking, use the history class
          assoc_history_class_name = "#{association.class_name}History"
          assoc_module = association.active_record.module_parent
          
          begin
            assoc_module.const_get(assoc_history_class_name)
            assoc_history_class_name = "#{assoc_module}::#{assoc_history_class_name}" unless assoc_history_class_name.match?(Regexp.new("#{assoc_module}::"))
          rescue
          end
          
          assoc_class = assoc_history_class_name.safe_constantize || OpenStruct.new(name: assoc_history_class_name)
          assoc_class_name = assoc_class.name
        else
          # No history table, use the original model
          assoc_class_name = association.class_name
        end

        case association.macro
        when :belongs_to
          # Start with all original association options
          options = association.options.dup
          
          # Override the class name and foreign key
          options[:class_name] = assoc_class_name
          options[:foreign_key] = assoc_foreign_key
          
          # For history associations, we need to handle snapshot filtering differently
          # We'll create the association but override the accessor method
          if assoc_class_name.match?(/History/)
            # Create the Rails association first
            belongs_to assoc_name, **options
            
            # Then override the accessor to filter by snapshot_id
            history_fk = association.class_name.gsub(/History$/, '').underscore + '_id'
            
            define_method("#{assoc_name}_with_snapshot") do
              return nil unless self[assoc_foreign_key]
              assoc_class.where(
                history_fk => self[assoc_foreign_key],
                snapshot_id: self.snapshot_id
              ).first
            end
            
            # Alias the original method and replace it
            alias_method "#{assoc_name}_without_snapshot", assoc_name
            alias_method assoc_name, "#{assoc_name}_with_snapshot"
          else
            belongs_to assoc_name, **options
          end
        when :has_one
          # Start with all original association options
          options = association.options.dup
          
          # Override the class name and keys
          options[:class_name] = assoc_class_name
          options[:foreign_key] = assoc_foreign_key
          options[:primary_key] = history_foreign_key
          
          if assoc_class_name.match?(/History/)
            # Create the Rails association first
            has_one assoc_name, **options
            
            # Then override the accessor to filter by snapshot_id
            hfk = history_foreign_key
            
            define_method("#{assoc_name}_with_snapshot") do
              assoc_class.where(
                assoc_foreign_key => self[hfk],
                snapshot_id: self.snapshot_id
              ).first
            end
            
            # Alias the original method and replace it
            alias_method "#{assoc_name}_without_snapshot", assoc_name
            alias_method assoc_name, "#{assoc_name}_with_snapshot"
          else
            has_one assoc_name, **options
          end
        when :has_many
          # Start with all original association options
          options = association.options.dup
          
          # Override the class name and keys
          options[:class_name] = assoc_class_name
          options[:foreign_key] = assoc_foreign_key
          options[:primary_key] = history_foreign_key
          
          if assoc_class_name.match?(/History/)
            # Create the Rails association first
            has_many assoc_name, **options
            
            # Then override the accessor to filter by snapshot_id
            hfk = history_foreign_key
            
            define_method("#{assoc_name}_with_snapshot") do
              assoc_class.where(
                assoc_foreign_key => self[hfk],
                snapshot_id: self.snapshot_id
              )
            end
            
            # Alias the original method and replace it
            alias_method "#{assoc_name}_without_snapshot", assoc_name
            alias_method assoc_name, "#{assoc_name}_with_snapshot"
          else
            has_many assoc_name, **options
          end
        end
      end

      #
      # The foreign key to the primary class.
      #
      # E.g. PostHistory.history_foreign_key => post_id
      #
      def history_foreign_key
        return @history_foreign_key if @history_foreign_key

        # Use the table name to generate the foreign key to properly handle namespaced models
        # E.g. EasyML::Column -> easy_ml_columns -> easy_ml_column_id
        @history_foreign_key = original_class.base_class.table_name.singularize.foreign_key
      end

    end

    def original_class
      self.class.original_class
    end

  private
    def dummy_instance
      return @dummy_instance if @dummy_instance

      # Only exclude history-specific columns
      cannot_keep_cols = %w(history_started_at history_ended_at history_user_id snapshot_id id)
      cannot_keep_cols += [self.class.history_foreign_key] 
      cannot_keep_cols.map!(&:to_s)

      attrs = attributes.clone
      # attrs[original_class.primary_key] = attrs[self.class.history_foreign_key]


      # Manually handle creating instance WITHOUT running find or initialize callbacks
      # We will manually run callbacks below
      # See: https://github.com/rails/rails/blob/95deab7b439abba23fdc4bd659116dab5dbe2606/activerecord/lib/active_record/core.rb#L487
      #
      attributes = original_class.attributes_builder.build_from_database(attrs.except(*cannot_keep_cols))
      instance = original_class.allocate

      # Set the internal attributes
      instance.instance_variable_set(:@attributes, attributes)
      instance.instance_variable_set(:@new_record, false)

      # Initialize internal variables without triggering callbacks
      instance.send(:init_internals)

      # Filter out any methods that are not overridden on the history class
      history_methods = self.class.instance_methods(false)
      history_class_location = Module.const_source_location(self.class.name).first 
      history_methods.select! do |method| 
        self.class.instance_method(method).source_location.first == history_class_location
      end
      history_methods += [:is_history_class?]

      history_methods.each do |method_name|
        instance.singleton_class.class_eval do 
          define_method(method_name) do |*args, &block|
            history_instance = instance.instance_variable_get(:@_history_instance)
            history_instance.send(method_name, *args, &block)
          end
        end
      end

      # For each association in the history class (including custom methods)
      associations_to_forward = self.class.reflect_on_all_associations.map(&:name)
      
      # Add custom association methods
      custom_methods = self.class.class_variable_get(:@@history_association_methods) rescue []
      associations_to_forward += custom_methods
      
      associations_to_forward.uniq.each do |assoc_name|
        # Define a method that forwards to the history association
        instance.singleton_class.class_eval do
          define_method(assoc_name) do |*args, &block|
            history_instance = instance_variable_get(:@_history_instance)
            history_instance.send(assoc_name, *args, &block)
          end
        end
      end

      instance.instance_variable_set(:@_history_instance, self)

      if instance.send(original_class.primary_key).present?
        instance.run_callbacks(:find)
      end
      instance.run_callbacks(:initialize)

      @dummy_instance = instance
    end

    def forward_method(method_name, *args, **kwargs, &block)
      dummy_instance.send(method_name, *args, **kwargs, &block)
    end
  end
end