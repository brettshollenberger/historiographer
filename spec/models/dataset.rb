class Dataset < ActiveRecord::Base
  include Historiographer
  self.table_name = "datasets"

  belongs_to :ml_model, class_name: "MLModel"
end