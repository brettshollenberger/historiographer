module Historiographer
  module Relation
    extend ActiveSupport::Concern

    def has_histories?
      self.klass.respond_to?(:history_class)
    end

    def update_all_without_history(updates)
      update_all(updates, false)
    end

    def update_all(updates, histories=true)
      if !histories || self.model.is_history_class?
        super(updates)
      else
        updates.symbolize_keys!
        model_changes = updates.except(:history_user_id)

        ActiveRecord::Base.transaction do
          changed_records = select do |record|
            !(record.attributes.symbolize_keys >= model_changes)
          end

          super(model_changes)
          bulk_record_history(self.reload.where(id: changed_records.pluck(:id)), updates)
        end
      end
    end

    def bulk_record_history(records, updates = {})
      now = UTC.now
      history_class = self.klass.history_class

      records.new.send(:history_user_absent_action) if updates[:history_user_id].nil?
      history_user_id = updates[:history_user_id]

      new_histories = records.map do |record|
        attrs = record.history_attrs(now: now)
        record.histories.build(attrs)
      end

      current_histories = history_class.current.where("#{history_class.history_foreign_key} IN (?)", records.map(&:id))

      current_histories.update_all(history_ended_at: now)

      history_class.import new_histories
    end

    def delete_all_without_history
      delete_all(nil, false)
    end

    def delete_all(options={}, histories=true)
      unless histories
        super()
      else
        ActiveRecord::Base.transaction do
          records = self
          history_class = records.first.class.history_class
          history_user_id = options[:history_user_id]
          records.first.send(:history_user_absent_action) if history_user_id.nil?
          now = UTC.now

          history_class.current.where("#{history_class.history_foreign_key} IN (?)", records.map(&:id)).update_all(history_ended_at: now)

          if records.first.respond_to?(:paranoia_destroy)
            new_histories = records.map do |record|
              attrs = record.history_attrs(now: now)
              attrs[:history_user_id] = history_user_id
              attrs[:deleted_at] = now
              record.histories.build(attrs)
            end
            history_class.import new_histories
          end

          super()
        end
      end
    end

    def destroy_all_without_history
      records.each(&:destroy_without_history).tap { reset }
    end

    def destroy_all(history_user_id: nil)
      records.each { |r| r.destroy(history_user_id: history_user_id) }.tap { reset }
    end
  end
end
