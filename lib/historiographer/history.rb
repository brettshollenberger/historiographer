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
      clear_validators!
      #
      # A History class (e.g. RetailerProductHistory) will gain
      # access to a current scope, returning
      # the most recent history.
      #
      scope :current, -> { where(history_ended_at: nil).order(id: :desc) }

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
      belongs_to :user, foreign_key: :history_user_id

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

      # Add method_added hook to the original class
      foreign_class.singleton_class.class_eval do
        # Keep track of original method_added if it exists
        if method_defined?(:method_added)
          alias_method :original_method_added, :method_added
        end

        method_map = Hash.new(0)
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

    end

    class_methods do
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
        assoc_history_class_name = "#{association.class_name}History"
        assoc_foreign_key = association.foreign_key

        # Skip if the association is already defined
        return if method_defined?(assoc_name)

        # Skip through associations to history classes to avoid infinite loops
        return if association.class_name.end_with?('History')

        # We're writing a belongs_to
        # The dataset belongs_to the datasource
        # dataset#datasource_id => datasource.id
        # 
        # For the history class, we're writing a belongs_to
        # the DatasetHistory belongs_to the DatasourceHistory
        # dataset_history#datasource_id => datasource_history.easy_ml_datasource_id
        #
        # The missing piece for us here is whatever DatasourceHistory would call easy_ml_datasource_id (history foreign key?)

        case association.macro
        when :belongs_to
          belongs_to assoc_name, ->(history_instance) {
            where(snapshot_id: history_instance.snapshot_id)
          }, class_name: assoc_history_class_name, foreign_key: assoc_foreign_key, primary_key: assoc_foreign_key
        when :has_one
          has_one assoc_name, ->(history_instance) {
            where(snapshot_id: history_instance.snapshot_id)
          }, class_name: assoc_history_class_name, foreign_key: assoc_foreign_key, primary_key: history_foreign_key
        when :has_many
          has_many assoc_name, ->(history_instance) {
            where(snapshot_id: history_instance.snapshot_id)
          }, class_name: assoc_history_class_name, foreign_key: assoc_foreign_key, primary_key: history_foreign_key
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

      cannot_keep_cols = %w(history_started_at history_ended_at history_user_id snapshot_id)
      cannot_keep_cols += [self.class.inheritance_column.to_sym] if self.original_class.sti_enabled?
      cannot_keep_cols += [self.class.history_foreign_key] 
      cannot_keep_cols.map!(&:to_s)

      attrs = attributes.clone
      attrs[original_class.primary_key] = attrs[self.class.history_foreign_key]

      instance = original_class.find_or_initialize_by(original_class.primary_key => attrs[original_class.primary_key])
      instance.assign_attributes(attrs.except(*cannot_keep_cols))
      @dummy_instance = instance
    end

    def forward_method(method_name, *args, &block)
      dummy_instance.send(method_name, *args, &block)
    end
  end
end