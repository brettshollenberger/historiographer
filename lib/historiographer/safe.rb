# Historiographer::Safe is intended to be used to migrate an existing model
# to Historiographer, not as a long-term solution.
#
# Historiographer will throw an error if a model is saved without a user present,
# unless you explicitly call save_without_history.
#
# Historiographer::Safe will not throw an error, but will rather produce a Rollbar,
# which enables a programmer to find all locations that need to be migrated,
# rather than allowing an unsafe migration to take place.
#
# Eventually the programmer is expected to replace Safe with Historiographer so
# that future programmers will get an error if they try to save without user_id.
#
module Historiographer
  module Safe
    extend ActiveSupport::Concern

    included do
      include Historiographer

      def should_validate_history_user_id_present?
        false
      end

      private

      def history_user_absent_action
        Rollbar.error("history_user_id must be passed in order to save record with histories! If you are in a context with no history_user_id, explicitly call #save_without_history")
      end
    end

  end
end
