class TestArticleHistory < ActiveRecord::Base
  include Historiographer::History
end