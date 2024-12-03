class MLModel < ActiveRecord::Base
  include Historiographer

  has_one :dataset
end