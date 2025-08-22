require 'spec_helper'

RSpec.describe 'Historiographer::Safe Integration' do
  # This test reproduces the exact error from a real Rails app where:
  # 1. WebsiteHistory is defined first and includes Historiographer::History
  # 2. Website is defined later and includes Historiographer::Safe
  # 3. The error occurs because foreign_class.constantize fails when Website isn't loaded yet
  
  context 'when history class is loaded before the main model' do
    before(:each) do
      # Ensure clean state
      Object.send(:remove_const, :RealAppWebsite) if defined?(RealAppWebsite)
      Object.send(:remove_const, :RealAppWebsiteHistory) if defined?(RealAppWebsiteHistory)
      
      # Create the tables
      ActiveRecord::Base.connection.create_table :real_app_websites, force: true do |t|
        t.string :name
        t.integer :project_id
        t.integer :user_id
        t.integer :template_id
        t.timestamps
      end
      
      ActiveRecord::Base.connection.create_table :real_app_website_histories, force: true do |t|
        t.integer :real_app_website_id, null: false
        t.string :name
        t.integer :project_id
        t.integer :user_id
        t.integer :template_id
        t.datetime :created_at, null: false
        t.datetime :updated_at, null: false
        t.datetime :history_started_at, null: false
        t.datetime :history_ended_at
        t.integer :history_user_id
        t.string :snapshot_id
        t.string :thread_id
      end
      
      ActiveRecord::Base.connection.add_index :real_app_website_histories, :real_app_website_id
      ActiveRecord::Base.connection.add_index :real_app_website_histories, :history_started_at
      ActiveRecord::Base.connection.add_index :real_app_website_histories, :history_ended_at
    end
    
    after(:each) do
      # Clean up tables
      ActiveRecord::Base.connection.drop_table :real_app_website_histories if ActiveRecord::Base.connection.table_exists?(:real_app_website_histories)
      ActiveRecord::Base.connection.drop_table :real_app_websites if ActiveRecord::Base.connection.table_exists?(:real_app_websites)
      
      # Clean up constants
      Object.send(:remove_const, :RealAppWebsiteHistory) if defined?(RealAppWebsiteHistory)
      Object.send(:remove_const, :RealAppWebsite) if defined?(RealAppWebsite)
    end
    
    it 'handles history class being defined before the main model exists' do
      # This is the exact scenario from the error report:
      # WebsiteHistory is loaded/required first (common in Rails autoloading)
      
      expect {
        class RealAppWebsiteHistory < ApplicationRecord
          self.table_name = 'real_app_website_histories'
          include Historiographer::History
        end
      }.not_to raise_error
      
      # At this point, RealAppWebsite doesn't exist yet
      # The history class should handle this gracefully
      expect(RealAppWebsiteHistory.foreign_class).to be_nil
      
      # Now define the main model (simulating Rails autoloading it later)
      class RealAppWebsite < ApplicationRecord
        self.table_name = 'real_app_websites'
        include Historiographer::Safe
      end
      
      # After the main model is defined, foreign_class should resolve
      expect(RealAppWebsiteHistory.foreign_class).to eq(RealAppWebsite)
      
      # And all functionality should work
      website = RealAppWebsite.create!(name: 'Test Site', history_user_id: 1)
      expect(website.histories.count).to eq(1)
      
      history = website.histories.first
      expect(history).to be_a(RealAppWebsiteHistory)
      expect(history.real_app_website_id).to eq(website.id)
      expect(history.name).to eq('Test Site')
    end
    
    it 'allows history class to define associations even when parent model is not loaded' do
      # Define a Deploy model for association testing
      ActiveRecord::Base.connection.create_table :deploys, force: true do |t|
        t.integer :real_app_website_history_id
        t.string :status
        t.timestamps
      end
      
      class Deploy < ApplicationRecord
        self.table_name = 'deploys'
      end
      
      # Define history class with associations before main model exists
      expect {
        class RealAppWebsiteHistory < ApplicationRecord
          self.table_name = 'real_app_website_histories'
          include Historiographer::History
          
          # This should work even though RealAppWebsite doesn't exist yet
          has_many :deploys, foreign_key: :real_app_website_history_id, dependent: :destroy
        end
      }.not_to raise_error
      
      # Now define the main model
      class RealAppWebsite < ApplicationRecord
        self.table_name = 'real_app_websites'
        include Historiographer::Safe
      end
      
      # Test that associations work
      website = RealAppWebsite.create!(name: 'Test Site', history_user_id: 1)
      history = website.histories.first
      
      deploy = Deploy.create!(real_app_website_history_id: history.id, status: 'pending')
      expect(history.deploys).to include(deploy)
      
      # Clean up
      ActiveRecord::Base.connection.drop_table :deploys
      Object.send(:remove_const, :Deploy)
    end
    
    it 'supports after_initialize Rails hook when available' do
      # Simulate Rails being available with after_initialize
      rails_app = double('Rails App')
      config = double('Rails Config')
      allow(config).to receive(:after_initialize).and_yield
      allow(rails_app).to receive(:config).and_return(config)
      allow(Rails).to receive(:application).and_return(rails_app)
      
      # Define history class
      class RealAppWebsiteHistory < ApplicationRecord
        self.table_name = 'real_app_website_histories'
        include Historiographer::History
      end
      
      # Define main model
      class RealAppWebsite < ApplicationRecord
        self.table_name = 'real_app_websites'
        include Historiographer::Safe
      end
      
      # The after_initialize should have set up associations
      expect(RealAppWebsiteHistory).to respond_to(:setup_history_associations)
      expect { RealAppWebsiteHistory.setup_history_associations }.not_to raise_error
    end
  end
end