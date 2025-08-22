class TestUser < ApplicationRecord
  include Historiographer
  has_many :test_websites, foreign_key: 'user_id'
end