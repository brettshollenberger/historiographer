class XGBoostHistory < ActiveRecord::Base
  include Historiographer::History
  self.table_name = "ml_model_histories"
end