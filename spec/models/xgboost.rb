class XGBoost < MLModel
  self.table_name = "ml_models"
  include Historiographer
end