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
      class_variable_set(:@@method_map, {})

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

            # Define the method in the history class
            foreign_class.history_class.set_method_map(method_name, false)
            foreign_class.history_class.class_eval do
              define_method(method_name) do |*args, &block|
                forward_method(method_name, *args, &block)
              end
            end
          ensure
            Thread.current[:defining_historiographer_method] = false
          end
        end
      end

      foreign_class.columns.map(&:name).each do |method_name|
        define_method(method_name) do |*args, &block|
          forward_method(method_name, *args, &block)
        end
      end

      # Add method_missing for any methods we might have missed
      def method_missing(method_name, *args, &block)
        original_class = self.class.class_variable_get(:@@original_class)
        if original_class.method_defined?(method_name)
          forward_method(method_name, *args, &block)
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

      # Enable STI for history classes
      if foreign_class.sti_enabled?
        self.inheritance_column = 'type'
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

      def method_added(method_name)
        set_method_map(method_name, true)
      end

      def set_method_map(method_name, is_overridden)
        mm = method_map
        mm[method_name.to_sym] = is_overridden
        class_variable_set(:@@method_map, mm)
      end

      def method_map
        unless class_variable_defined?(:@@method_map)
          class_variable_set(:@@method_map, {})
        end
        class_variable_get(:@@method_map) || {}
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

        # Define the scope to filter by snapshot_id for history associations
        scope = if assoc_class_name.match?(/History/)
                  ->(history_instance) { where(snapshot_id: history_instance.snapshot_id) }
                else
                  ->(history_instance) { all }
                end

        case association.macro
        when :belongs_to
          belongs_to assoc_name, scope, class_name: assoc_class_name, foreign_key: assoc_foreign_key, primary_key: assoc_foreign_key
        when :has_one
          has_one assoc_name, scope, class_name: assoc_class_name, foreign_key: assoc_foreign_key, primary_key: history_foreign_key
        when :has_many
          has_many assoc_name, scope, class_name: assoc_class_name, foreign_key: assoc_foreign_key, primary_key: history_foreign_key
        end
      end

      #
      # The foreign key to the primary class.
      #
      # E.g. PostHistory.history_foreign_key => post_id
      #
      def history_foreign_key
        return @history_foreign_key if @history_foreign_key

        # CAN THIS BE TABLE OR MODEL?
        @history_foreign_key = sti_base_class.name.singularize.foreign_key
      end

      def sti_base_class
        return @sti_base_class if @sti_base_class

        base_name = name.gsub(/History$/, '')
        base_class = base_name.constantize
        while base_class.superclass != ActiveRecord::Base
          base_class = base_class.superclass
        end
        @sti_base_class = base_class
      end
    end

    def original_class
      self.class.original_class
    end

  private
    def dummy_instance
      return @dummy_instance if @dummy_instance

      # Only exclude history-specific columns
      cannot_keep_cols = %w(history_started_at history_ended_at history_user_id snapshot_id)
      cannot_keep_cols += [self.class.history_foreign_key] 
      cannot_keep_cols.map!(&:to_s)

      attrs = attributes.clone
      attrs[original_class.primary_key] = attrs[self.class.history_foreign_key]

      if original_class.sti_enabled?
        # Remove History suffix from type if present
        attrs[original_class.inheritance_column] = attrs[original_class.inheritance_column]&.gsub(/History$/, '')
      end

      # Create instance with all attributes except history-specific ones
      instance = original_class.instantiate(attrs.except(*cannot_keep_cols))

      if instance.valid?
        if instance.send(original_class.primary_key).present?
          instance.run_callbacks(:find)
        end
        instance.run_callbacks(:initialize)
      end

      # Filter out any methods that are not overridden on the history class
      history_methods = self.class.instance_methods(false)
      history_class_location = Module.const_source_location(self.class.name).first 
      history_methods.select! do |method| 
        self.class.instance_method(method).source_location.first == history_class_location
      end

      history_methods.each do |method_name|
        instance.singleton_class.class_eval do 
          define_method(method_name) do |*args, &block|
            history_instance = instance.instance_variable_get(:@_history_instance)
            history_instance.send(method_name, *args, &block)
          end
        end
      end

      # For each association in the history class
      self.class.reflect_on_all_associations.each do |reflection|
        # Define a method that forwards to the history association
        instance.singleton_class.class_eval do
          define_method(reflection.name) do |*args, &block|
            history_instance = instance.instance_variable_get(:@_history_instance)
            history_instance.send(reflection.name, *args, &block)
          end
        end
      end

      # Override class method to return history class
      instance.singleton_class.class_eval do
        define_method(:class) do
          history_instance = instance.instance_variable_get(:@_history_instance)
          history_instance.class
        end
      end

      instance.instance_variable_set(:@_history_instance, self)
      @dummy_instance = instance
    end

    def forward_method(method_name, *args, &block)
      if method_name == :class || method_name == 'class'
        self.class
      else
        dummy_instance.send(method_name, *args, &block)
      end
    end
  end
end