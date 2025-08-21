class ProjectFile < ApplicationRecord
  include Historiographer::Safe

  belongs_to :project
end