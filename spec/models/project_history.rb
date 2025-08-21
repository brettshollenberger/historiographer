class ProjectHistory < ActiveRecord::Base
  self.table_name = "project_histories"
  include Historiographer::History
end