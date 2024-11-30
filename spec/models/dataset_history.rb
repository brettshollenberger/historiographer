class DatasetHistory < ActiveRecord::Base
  include Historiographer::History
  self.table_name = "dataset_histories"
end