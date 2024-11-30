class AuthorHistory < ActiveRecord::Base
  include Historiographer::History
  self.table_name = "author_histories"
end