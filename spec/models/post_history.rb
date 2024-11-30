class PostHistory < ActiveRecord::Base
  self.table_name = "post_histories"
  include Historiographer::History

  def locked_value
    "My Great Post v100"
  end
end
