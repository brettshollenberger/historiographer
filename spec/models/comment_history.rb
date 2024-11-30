
class CommentHistory < ActiveRecord::Base
  self.table_name = "comment_histories"
  include Historiographer::History
end
