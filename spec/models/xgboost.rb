class XGBoost < MLModel
  self.inheritance_column = :model_type
  self.table_name = "ml_models"
  include Historiographer
end