# frozen_string_literal: true

class WebsiteHistory < ApplicationRecord
  include Historiographer::History
  
  has_many :deploys
end