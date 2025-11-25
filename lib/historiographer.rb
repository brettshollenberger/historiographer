# frozen_string_literal: true

require 'active_support/all'
require 'securerandom'
require_relative './historiographer/configuration'
require_relative './historiographer/history'
require_relative './historiographer/postgres_migration'
require_relative './historiographer/safe'
require_relative './historiographer/relation'
require_relative './historiographer/silent'

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
  class HistoryInsertionError < StandardError; end

  UTC = Time.now.in_time_zone('UTC').time_zone

  included do |base|
    after_save :record_history, if: :should_record_history?
    validate :validate_history_user_id_present, if: :should_validate_history_user_id_present?

    def should_alert_history_user_id_present?
      !snapshot_mode? && !is_history_class? && Thread.current[:skip_history_user_id_validation] != true
    end

    def should_validate_history_user_id_present?
      !snapshot_mode? && !is_history_class? && Thread.current[:skip_history_user_id_validation] != true
    end

    def validate_history_user_id_present
      if should_validate_history_user_id_present? && (@no_history.nil? && (!history_user_id.present? || !history_user_id.is_a?(Integer)))
        errors.add(:history_user_id, 'must be an integer')
      end
    end

    alias_method :destroy_without_history, :destroy

    def destroy_with_history(history_user_id: nil)
      history_user_absent_action if history_user_id.nil?

      current_history = histories.where(history_ended_at: nil).order('id desc').limit(1).last
      current_history.update_columns(history_ended_at: UTC.now) if current_history.present?

      if respond_to?(:paranoia_destroy)
        self.history_user_id = history_user_id
        paranoia_destroy
      else
        @no_history = true
        destroy_without_history
        @no_history = false
      end
      true
    end

    alias_method :destroy, :destroy_with_history

    def assign_attributes(new_attributes)
      huid = new_attributes[:history_user_id]

      if huid.present?
        self.class.nested_attributes_options.each do |association, _|
          reflection = self.class.reflect_on_association(association)
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

    def historiographer_changes?
      case Rails.version.to_f
      when 0..5 then changed? && valid?
        raise 'Unsupported Rails version'
      when 5.1..8 then saved_changes?
      else
      end
    end

    #
    # If there are any changes, and the model is valid,
    # and we're not force-overriding history recording,
    # then record history after successful save.
    #
    def should_record_history?
      return false if snapshot_mode?
      return false if is_history_class?

      historiographer_changes? && !@no_history
    end

    def history_user_id=(value)
      if is_history_class?
        write_attribute(:history_user_id, value)
      else
        @history_user_id = value
      end
    end

    def history_user_id
      if is_history_class?
        read_attribute(:history_user_id)
      else
        @history_user_id
      end
    end

    class_name = "#{base.name}History"

    begin
      class_name.constantize
    rescue NameError
      # Get the base table name without _histories suffix
      base_table = base.table_name.singularize.sub(/_histories$/, '')
      
      history_class_initializer = Class.new(ActiveRecord::Base) do
        self.table_name = "#{base_table}_histories"
      end

      # Split the class name into module parts and the actual class name
      module_parts = class_name.split('::')
      final_class_name = module_parts.pop

      # Navigate through module hierarchy
      target_module = module_parts.inject(Object) do |mod, module_name|
        mod.const_defined?(module_name) ? mod.const_get(module_name) : mod.const_set(module_name, Module.new)
      end

      # Set the constant in the correct module
      history_class = target_module.const_set(final_class_name, history_class_initializer)
      
      # Now that the class is named, include the History module and extend class methods
      history_class.send(:include, Historiographer::History)
    end

    klass = class_name.constantize

    # Hook into the association building process
    base.singleton_class.prepend(Module.new do
      def belongs_to(name, scope = nil, **options, &extension)
        super
        return if is_history_class?
        history_class.define_history_association(name)
      end

      def has_one(name, scope = nil, **options, &extension)
        super
        return if is_history_class?
        history_class.define_history_association(name)
      end

      def has_many(name, scope = nil, **options, &extension)
        super
        return if is_history_class?
        history_class.define_history_association(name)
      end

      def has_and_belongs_to_many(name, scope = nil, **options, &extension)
        super
        return if is_history_class?
        history_class.define_history_association(name)
      end
    end)

    def histories
      history_class.where(history_class.history_foreign_key => self.send(self.class.primary_key))
    end

    def current_history
      history_class.where(history_class.history_foreign_key => self.send(self.class.primary_key)).current&.first
    end

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
        any_changes = opts.keys.reject { |k| k == 'id' }.any?

        transaction do
          persisted = super(opts)

          record_history if any_changes && persisted
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
    
    def snapshot(tree = {}, snapshot_id = nil)
      return if is_history_class?

      without_history_user_id do
        # Use SecureRandom.uuid instead of timestamp for snapshot_id
        snapshot_id ||= SecureRandom.uuid
        history_class = self.class.history_class
        primary_key = self.class.primary_key
        foreign_key = history_class.history_foreign_key
        attrs = attributes.clone
        existing_snapshot = history_class.where(foreign_key => attrs[primary_key], snapshot_id: snapshot_id)
        return if existing_snapshot.present?

        null_snapshot = history_class.where(foreign_key => attrs[primary_key], snapshot_id: nil).first
        snapshot = nil
        if null_snapshot.present?
          null_snapshot.update(snapshot_id: snapshot_id)
          snapshot = null_snapshot
        else
          snapshot = record_history(snapshot_id: snapshot_id)
        end

        # Recursively snapshot associations, avoiding infinite loops
        self.class.reflect_on_all_associations.each do |association|
          # Skip associations to models without primary keys (e.g., database views)
          association_class = association.klass rescue nil
          next if association_class.nil?
          next if association_class.primary_key.nil?
          
          associated_records = send(association.name)&.reload
          if associated_records.respond_to?(:order)
            associated_records = associated_records.order(id: :asc)
          end
          Array(associated_records).each do |record|
            model_name = record.class.name
            record_id = record.id

            tree[model_name] ||= {}
            next if tree[model_name][record_id]

            new_tree = tree.deep_dup
            new_tree[model_name][record_id] = true

            record.snapshot(new_tree, snapshot_id) if record.respond_to?(:snapshot)
          end
        end

        snapshot
      end
    end

    def history_class
      self.class.history_class
    end

    def history_attrs(snapshot_id: nil, now: nil)
      attrs = attributes.clone
      history_class = self.class.history_class
      foreign_key = history_class.history_foreign_key

      attrs = attrs.stringify_keys
      allowed_columns = self.class.columns.map(&:name)
      attrs.select! { |k,v| allowed_columns.include?(k) }.to_h

      now ||= UTC.now
      attrs.merge!(foreign_key => attrs['id'], history_started_at: now, history_user_id: history_user_id)
      attrs.merge!(snapshot_id: snapshot_id) if snapshot_id.present?

      attrs = attrs.except('id')
      attrs.stringify_keys!

      attrs
    end

    def snapshots
      histories.where.not(snapshot_id: nil)
    end

    def latest_snapshot
      snapshots.order('id DESC').limit(1)&.first || history_class.none
    end

    private

    def history_user_absent_action
      raise HistoryUserIdMissingError, 'history_user_id must be passed in order to save record with histories! If you are in a context with no history_user_id, explicitly call #save_without_user'
    end

    #
    # Save a record of the most recent changes, with the current
    # time as history_started_at, and the provided user as history_user_id.
    #
    # Find the most recent history, and update its history_ended_at timestamp
    #
    def record_history(snapshot_id: nil)
      history_user_absent_action if history_user_id.nil? && should_alert_history_user_id_present?

      now = UTC.now
      attrs = history_attrs(snapshot_id: snapshot_id, now: now)
      current_history = histories.where(history_ended_at: nil).order('id desc').limit(1).last

      if history_class.history_foreign_key.present? && history_class.present?
        if defined?(ActiveRecord::ConnectionAdapters::OracleEnhanced)
          # Oracle Enhanced gem does not support insert_all
          instance = history_class.new(attrs)
          unless instance.save
            return check_duplicate_history(attrs)
          end
        else
          result = history_class.insert_all([attrs])
          # Check if the insertion was successful
          if result.rows.empty?
            # insert_all returned empty rows, likely due to a duplicate/conflict
            return check_duplicate_history(attrs)
          end
          inserted_id = result.rows.first.first if history_class.primary_key == 'id'
          instance = history_class.find(inserted_id)
        end
        current_history.update_columns(history_ended_at: now) if current_history.present?
        instance
      else
        raise 'Need foreign key and history class to save history!'
      end
    end

    def check_duplicate_history(attrs)
      # Try to find the existing record that prevented insertion
      foreign_key = history_class.history_foreign_key
      existing_history = history_class.where(
        foreign_key => attrs[foreign_key],
        history_started_at: attrs['history_started_at']
      ).first

      if existing_history
        # A duplicate history already exists (race condition or retry)
        # This is acceptable - return the existing history
        Rails.logger.warn("Duplicate history detected for #{self.class.name} ##{id} at #{attrs['history_started_at']}. Using existing history record ##{existing_history.id}.") if Rails.logger
        current_history.update_columns(history_ended_at: now) if current_history.present?
        existing_history
      else
        history_class.create!(attrs) # This will raise the correct error since it will fail the unique constraint
      end
    end

    def without_history_user_id
      Thread.current[:skip_history_user_id_validation] = true
      yield
    ensure
      Thread.current[:skip_history_user_id_validation] = false
    end
  end

  class_methods do
    def latest_snapshot
      instance = history_class.latest_snapshot
      instance.is_a?(history_class) ? instance : nil
    end

    def is_history_class?
      name.match?(/History$/)
    end
    #
    # E.g. SponsoredProductCampaign => SponsoredProductCampaignHistory
    #
    def history_class
      if is_history_class?
        nil
      else
        "#{name}History".constantize
      end
    end

    def relation
      super.tap { |r| r.extend Historiographer::Relation }
    end

    def historiographer_mode(mode)
      @historiographer_mode = mode
    end

    def get_historiographer_mode
      @historiographer_mode || Historiographer::Configuration.mode
    end

  end

  def is_history_class?
    self.class.is_history_class?
  end

  def snapshot_mode?
    (self.class.get_historiographer_mode.to_sym == :snapshot_only)
  end
end
