class TemplateFile < ApplicationRecord
  include Historiographer
  
  belongs_to :template
end