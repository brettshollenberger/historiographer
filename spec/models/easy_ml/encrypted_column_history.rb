module EasyML
  class EncryptedColumnHistory < ActiveRecord::Base
    self.inheritance_column = :column_type
    self.table_name = "easy_ml_column_histories"
    include Historiographer::History
  end
end