# frozen_string_literal: true

# Historiographer::Silent is intended to be used to migrate an existing model
# to Historiographer, not as a long-term solution.
#
# Historiographer will throw an error if a model is saved without a user present,
# unless you explicitly call save_without_history.
#
# Historiographer::Silent will not throw an error, and will not produce a Rollbar
#
module Historiographer
  module Silent
    extend ActiveSupport::Concern

    included do
      include Historiographer

      def should_validate_history_user_id_present?
        false
      end

      private

      def history_user_absent_action
        # noop
      end
    end
  end
end
