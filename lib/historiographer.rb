require "active_support/all"
require_relative "./historiographer/history"
require_relative "./historiographer/postgres_migration"
require_relative "./historiographer/safe"

# Historiographer takes "histories" (think audits or snapshots) of your model whenever you make changes.
#
# Core business data stored in histories can never be changed or destroyed (at least not from Rails-land), offering you
# a little more peace of mind (just a little).
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# A little example:
#
# photo = Photo.create(file: "cool.jpg")
# photo.histories # => [ <#PhotoHistory file: cool.jpg > ]
#
# photo.file = "fun.jpg"
# photo.save!
# photo.histories.reload # => [ <#PhotoHistory file: cool.jpg >, <#PhotoHistory file: fun.jpg> ]
#
# photo.histories.last.destroy! # => false
#
# photo.histories.last.update!(file: "bad.jpg") # => false
#
# photo.histories.last.file = "bad.jpg"
# photo.histories.last.save! # => false
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# How to use:
#
# 1) Add historiographer to your apps dependencies folder
#
# Ex: sudo ln -s ../../../shared/historiographer historiographer
#
# 2) Add historiographer to your apps gem file and bundle
#
# gem 'historiographer', path: 'dependencies/historiographer', require: 'historiographer'
#
# 3) Create a primary table
#
# create_table :photos do |t|
#   t.string :file
# end
#
# 4) Create history table. 't.histories' pulls in all the primary tables attributes plus a few required by historiographer.
#
# require "historiographer/postgres_migration"
# class CreatePhotoHistories < ActiveRecord::Migration
#   def change
#     create_table :photo_histories do |t|
#       t.histories
#     end
#   end
# end
#
# 5) Include Historiographer in the primary class:
#
# class Photo < ActiveRecord::Base
#   include Historiographer
# end
#
# 6) Create a history class
#
# class PhotoHistory < ActiveRecord::Base (or whereever your app inherits from. Ex CPG: CpgConnection, Shoppers: ShoppersRecord, etc)
# end
#
# 7) Enjoy!
#
module Historiographer
  extend ActiveSupport::Concern

  class HistoryUserIdMissingError < StandardError; end

  UTC = Time.now.in_time_zone("UTC").time_zone

  included do |base|
    after_save :record_history, if: :should_record_history?
    validate :validate_history_user_id_present, if: :should_validate_history_user_id_present?

    def should_validate_history_user_id_present?
      true
    end

    def validate_history_user_id_present
      if @no_history.nil? && (!history_user_id.present? || !history_user_id.is_a?(Integer))
        errors.add(:history_user_id, "must be an integer")
      end
    end

    def assign_attributes(new_attributes)
      huid = new_attributes[:history_user_id]

      if huid.present?
        self.class.nested_attributes_options.each do |association, _|
          reflection  = self.class.reflect_on_association(association)
          assoc_attrs = new_attributes["#{association}_attributes"]

          if assoc_attrs.present?
            if reflection.collection?
              assoc_attrs.values.each do |hash|
                hash.merge!(history_user_id: huid)
              end
            else
              assoc_attrs.merge!(history_user_id: huid)
            end
          end
        end
      end

      super
    end

    #
    # If there are any changes, and the model is valid,
    # and we're not force-overriding history recording,
    # then record history after successful save.
    #
    def should_record_history?
      changes.keys.any? && valid? && !@no_history
    end

    attr_accessor :history_user_id

    class_name = "#{base.name}History"

    if base.respond_to?(:histories)
      raise "#{base} already has histories. Talk to Brett if this is a legit use case."
    else
      has_many :histories, class_name: class_name
      has_one :current_history, -> { current }, class_name: class_name
    end

    begin
      class_name.constantize
    rescue
      history_class_initializer = Class.new(ActiveRecord::Base) do
      end

      Object.const_set(class_name, history_class_initializer)
    end

    klass = class_name.constantize

    klass.send(:include, Historiographer::History) unless klass.ancestors.include?(Historiographer::History)

    #
    # The acts_as_paranoid gem, which we tend to use with our History classes,
    # uses update_columns to update deleted_at fields.
    #
    # In order to make sure these changes are persisted into Histories objects,
    # we also have to record history here.
    #
    module UpdateColumnsWithHistory
      def update_columns(*args)
        opts = args.extract_options!
        any_changes = opts.keys.reject { |k| k == "id" }.any?

        transaction do
          persisted = super(opts)

          if any_changes && persisted
            record_history
          end
        end
      end
    end
    base.send(:prepend, UpdateColumnsWithHistory)

    def save_without_history(*args, &block)
      @no_history = true
      save(*args, &block)
      @no_history = false
    end

    def save_without_history!(*args, &block)
      @no_history = true
      save!(*args, &block)
      @no_history = false
    end

    private

    def history_user_absent_action
      raise HistoryUserIdMissingError.new("history_user_id must be passed in order to save record with histories! If you are in a context with no history_user_id, explicitly call #save_without_user")
    end

    #
    # Save a record of the most recent changes, with the current
    # time as history_started_at, and the provided user as history_user_id.
    #
    # Find the most recent history, and update its history_ended_at timestamp
    #
    def record_history
      history_user_absent_action if history_user_id.nil?

      attrs         = attributes.clone
      history_class = self.class.history_class
      foreign_key   = history_class.history_foreign_key

      now = UTC.now
      attrs.merge!(foreign_key => attrs["id"], history_started_at: now, history_user_id: history_user_id)

      attrs = attrs.except("id")

      current_history = histories.where(history_ended_at: nil).order("id desc").limit(1).last

      unless foreign_key.present? && history_class.present?
        raise "Need foreign key and history class to save history!"
      else
        history_class.create!(attrs)
        current_history.update!(history_ended_at: now) if current_history.present?
      end
    end
  end

  class_methods do

    #
    # E.g. SponsoredProductCampaign => SponsoredProductCampaignHistory
    #
    def history_class
      "#{name}History".constantize
    end
  end
end
