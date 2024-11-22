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
      original_class_name = base.name.gsub(/History$/) {}        # e.g. "RetailerProductHistory" => "RetailerProduct"
      original_class = original_class_name.constantize
      association_name = original_class_name.split("::").last.underscore.to_sym # e.g. "RetailerProduct" => :retailer_product

      # Store the original class for method delegation
      class_variable_set(:@@original_class, original_class)

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
        belongs_to association_name, class_name: original_class_name
      end

      # Enable STI for history classes
      if original_class.sti_enabled?
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
      original_class.reflect_on_all_associations.each do |association|
        define_history_association(association)
      end

    end

    class_methods do
      def table_name=(table_name)
        if table_name.end_with?('_histories')
          @table_name = table_name
        else
          @table_name = table_name.singularize + "_histories"
        end
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
        assoc_history_class_name = "#{association.class_name}History"
        assoc_foreign_key = association.foreign_key

        # Skip through associations to history classes to avoid infinite loops
        return if association.class_name.end_with?('History')
        base_module = association.active_record.name.split("::")[0..-2].join("::").try(:constantize) || Object
        klass = base_module.const_get(association.class_name)
        is_sti = klass.respond_to?(:sti_enabled?) && klass.sti_enabled?

        case association.macro
        when :belongs_to
          options = {}
          if association.options.key?(:polymorphic)
            options.merge!(polymorphic: true, foreign_key: assoc_foreign_key, primary_key: association.active_record.primary_key)
          else
            options.merge!(class_name: assoc_history_class_name, foreign_key: assoc_foreign_key, primary_key: assoc_foreign_key)
          end
          belongs_to assoc_name, ->(history_instance) {
            where(snapshot_id: history_instance.snapshot_id)
          }, **options
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
  end
end