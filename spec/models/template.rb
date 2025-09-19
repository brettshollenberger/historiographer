class Template < ApplicationRecord
  include Historiographer

  has_many :template_files, dependent: :destroy
  has_many :websites
end