module EasyML
  class Column < ActiveRecord::Base
    self.table_name = "easy_ml_columns"
    self.inheritance_column = "column_type"
    include Historiographer
  end
end
