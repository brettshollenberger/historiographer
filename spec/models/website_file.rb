class WebsiteFile < ApplicationRecord
  include Historiographer
  
  belongs_to :website
end