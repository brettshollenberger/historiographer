class TestCategory < ActiveRecord::Base
  include Historiographer
  # Association will be defined later to avoid circular dependency
end