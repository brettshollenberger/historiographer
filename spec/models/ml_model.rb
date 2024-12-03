class MLModel < ActiveRecord::Base
  self.inheritance_column = "model_type"
  include Historiographer

  has_one :dataset
end