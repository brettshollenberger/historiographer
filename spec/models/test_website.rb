class TestWebsite < ApplicationRecord
  include Historiographer
  belongs_to :user, class_name: 'TestUser', foreign_key: 'user_id', optional: true
end