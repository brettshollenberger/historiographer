class Author < ActiveRecord::Base
  include Historiographer
  has_many :comments
  has_many :posts
end