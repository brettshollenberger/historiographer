class ThingWithCompoundIndexHistory < ActiveRecord::Base
  include Historiographer::History
  self.table_name = "thing_with_compound_index_histories"
end