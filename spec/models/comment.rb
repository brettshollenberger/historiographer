class Comment < ActiveRecord::Base
  include Historiographer
  belongs_to :post
  belongs_to :author
end
