class Author < ActiveRecord::Base
  include Historiographer
  has_many :comments
  has_many :posts
  has_many :bylines  # This model doesn't have history tracking
end