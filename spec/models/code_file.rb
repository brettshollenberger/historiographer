class CodeFile < ApplicationRecord
  # This is a read-only model backed by a database view
  # The view merges template_files and website_files
  
  self.table_name = 'code_files'
  self.primary_key = nil # View doesn't have a primary key
  
  belongs_to :website
  
  # Default ordering since the view has no primary key
  default_scope { order(created_at: :desc, path: :asc) }
  
  def readonly?
    true
  end
end