
class SafePostHistory < ActiveRecord::Base
  self.table_name = "safe_post_histories"
  include Historiographer::History
end