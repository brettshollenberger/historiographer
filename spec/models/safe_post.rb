
class SafePost < ActiveRecord::Base
  include Historiographer::Safe
  acts_as_paranoid
end
