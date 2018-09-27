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
      # Although we never want there to be more than 1 current history,
      # in the off chance this invariant is broken, this method is
      # guaranteed to only return an array containing the most recent history.
      #
      scope :current, -> { where(history_ended_at: nil).order(id: :desc).limit(1) }

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
      association_name   = foreign_class_name.underscore.to_sym # e.g. "RetailerProduct"        => :retailer_product

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
      def save(*args)
        if persisted? && (changes.keys - %w(history_ended_at)).any?
          false
        else
          super
        end
      end

      def save!(*args)
        if persisted? && (changes.keys - %w(history_ended_at)).any?
          false
        else
          super
        end
      end
    end

    class_methods do

      #
      # The foreign key to the primary class.
      #
      # E.g. PostHistory.history_foreign_key => post_id
      #
      def history_foreign_key
        name.gsub(/History$/) {}.foreign_key
      end
    end
  end
end
