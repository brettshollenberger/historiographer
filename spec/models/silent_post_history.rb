class SilentPostHistory < ActiveRecord::Base
  self.table_name = "silent_post_histories"
  include Historiographer::History
end