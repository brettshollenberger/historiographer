class Website < ApplicationRecord
  include Historiographer
  
  belongs_to :template, optional: true
  has_many :website_files, dependent: :destroy
  has_many :code_files
end