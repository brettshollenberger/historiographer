class Byline < ActiveRecord::Base
  # Note: This model does NOT include Historiographer
  belongs_to :author
end