class PrivatePostHistory < ActiveRecord::Base
  self.table_name = "post_histories"
  include Historiographer::History
end
