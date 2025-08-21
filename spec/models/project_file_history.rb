class ProjectFileHistory < ActiveRecord::Base
  self.table_name = "project_file_histories"
  include Historiographer::History
end