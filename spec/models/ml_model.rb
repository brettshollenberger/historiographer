class MLModel < ActiveRecord::Base
  self.table_name = "ml_models"
  self.inheritance_column = :model_type
  include Historiographer

  has_one :dataset
end