module EasyML
  class EncryptedColumnHistory < ActiveRecord::Base
    self.table_name = "easy_ml_column_histories"
    include Historiographer::History
  end
end