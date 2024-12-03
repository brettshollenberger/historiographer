class XGBoost < MLModel
  self.table_name = "ml_models"
  self.inheritance_column = "model_type"
  include Historiographer
  after_initialize :set_defaults

  def set_defaults
    write_attribute(:model_type, "XGBoost")
  end
end