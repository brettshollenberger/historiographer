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
      foreign_class = foreign_class_name.constantize
      association_name   = foreign_class_name.split("::").last.underscore.to_sym # e.g. "RetailerProduct" => :retailer_product

      # Store the original class for method delegation
      class_variable_set(:@@original_class, foreign_class)

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
      unless foreign_class.ancestors.include?(Historiographer::Silent)
        belongs_to :user, foreign_key: :history_user_id
      end

      # Add method_added hook to the original class
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
            return if foreign_class.history_class.method_defined?(method_name)

            foreign_class.history_class.class_eval do
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
        (foreign_class.columns.map(&:name) - ["id"]).each do |method_name|
          define_method(method_name) do |*args, **kwargs, &block|
            forward_method(method_name, *args, **kwargs, &block)
          end
        end
      rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished
        # Table might not exist yet during setup
      end

      # Add method_missing for any methods we might have missed
      def method_missing(method_name, *args, **kwargs, &block)
        original_class = self.class.class_variable_get(:@@original_class)
        if original_class.method_defined?(method_name)
          forward_method(method_name, *args, **kwargs, &block)
        else
          super
        end
      end

      def respond_to_missing?(method_name, include_private = false)
        original_class = self.class.class_variable_get(:@@original_class)
        original_class.method_defined?(method_name) || super
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
      
      # Dynamically define associations on the history class
      foreign_class.reflect_on_all_associations.each do |association|
        define_history_association(association)
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
        unless class_variable_defined?(:@@original_class)
          class_variable_set(:@@original_class, self.name.gsub(/History$/, '').constantize)
        end

        class_variable_get(:@@original_class)
      end

      def define_history_association(association)
        if association.is_a?(Symbol) || association.is_a?(String)
          association = original_class.reflect_on_association(association)
          # If the association doesn't exist on the original class, skip it
          return unless association
        end
        
        assoc_name = association.name
        assoc_module = association.active_record.module_parent
        assoc_history_class_name = "#{association.class_name}History"

        begin
          assoc_module.const_get(assoc_history_class_name)
          assoc_history_class_name = "#{assoc_module}::#{assoc_history_class_name}" unless assoc_history_class_name.match?(Regexp.new("#{assoc_module}::"))
        rescue
        end

        assoc_foreign_key = association.foreign_key

        # Skip through associations to history classes to avoid infinite loops
        return if association.class_name.end_with?('History')

        # Always use the history class if it exists
        assoc_class = assoc_history_class_name.safe_constantize || OpenStruct.new(name: association.class_name)
        assoc_class_name = assoc_class.name

        case association.macro
        when :belongs_to
          # For belongs_to associations, if the target is a history class, we need special handling
          if assoc_class_name.match?(/History/)
            # Override the association method to filter by snapshot_id
            # The history class uses <model>_id as the foreign key (e.g., author_id for AuthorHistory)
            history_fk = association.class_name.gsub(/History$/, '').underscore + '_id'
            
            # Track this custom method
            methods_list = class_variable_get(:@@history_association_methods) rescue []
            methods_list << assoc_name
            class_variable_set(:@@history_association_methods, methods_list)
            
            define_method(assoc_name) do
              return nil unless self[assoc_foreign_key]
              assoc_class.where(
                history_fk => self[assoc_foreign_key],
                snapshot_id: self.snapshot_id
              ).first
            end
          else
            # Start with all original association options
            options = association.options.dup
            
            # Override only the specific options we need to change
            options[:class_name] = assoc_class_name
            options[:foreign_key] = assoc_foreign_key
            
            belongs_to assoc_name, **options
          end
        when :has_one
          if assoc_class_name.match?(/History/)
            hfk = history_foreign_key
            
            # Track this custom method
            methods_list = class_variable_get(:@@history_association_methods) rescue []
            methods_list << assoc_name
            class_variable_set(:@@history_association_methods, methods_list)
            
            define_method(assoc_name) do
              assoc_class.where(
                assoc_foreign_key => self[hfk],
                snapshot_id: self.snapshot_id
              ).first
            end
          else
            # Start with all original association options
            options = association.options.dup
            
            # Override only the specific options we need to change
            options[:class_name] = assoc_class_name
            options[:foreign_key] = assoc_foreign_key
            options[:primary_key] = history_foreign_key
            
            has_one assoc_name, **options
          end
        when :has_many
          if assoc_class_name.match?(/History/)
            hfk = history_foreign_key
            # Track this custom method
            methods_list = class_variable_get(:@@history_association_methods) rescue []
            methods_list << assoc_name
            class_variable_set(:@@history_association_methods, methods_list)
            
            define_method(assoc_name) do
              assoc_class.where(
                assoc_foreign_key => self[hfk],
                snapshot_id: self.snapshot_id
              )
            end
          else
            # Start with all original association options
            options = association.options.dup
            
            # Override only the specific options we need to change
            options[:class_name] = assoc_class_name
            options[:foreign_key] = assoc_foreign_key
            options[:primary_key] = history_foreign_key
            
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