class Project < ApplicationRecord
  include Historiographer::Safe
  has_many :files, class_name: "ProjectFile"
end