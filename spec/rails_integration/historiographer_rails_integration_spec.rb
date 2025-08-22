# frozen_string_literal: true

require 'combustion_helper'

RSpec.describe 'Historiographer Rails Integration', type: :model do
  describe 'when WebsiteHistory is loaded before Website (Rails autoloading scenario)' do
    it 'handles the load order gracefully' do
      expect(defined?(WebsiteHistory)).to be_truthy
      expect(WebsiteHistory.ancestors).to include(Historiographer::History)
      
      expect(defined?(Website)).to be_truthy
      expect(Website.ancestors).to include(Historiographer::Safe)
      
      expect(WebsiteHistory.foreign_class).to eq(Website)
      
      expect(WebsiteHistory).to respond_to(:setup_history_associations)
      expect(WebsiteHistory).to respond_to(:original_class)
      
      expect { WebsiteHistory.setup_history_associations }.not_to raise_error
    end
    
    it 'allows creating and querying history records' do
      user = User.create!(name: 'Test User')
      
      website = Website.create!(
        name: 'Production Site',
        project_id: 1,
        user_id: user.id,
        history_user_id: user.id
      )
      
      expect(website.histories.count).to eq(1)
      
      history = website.histories.first
      expect(history).to be_a(WebsiteHistory)
      expect(history.website_id).to eq(website.id)
      expect(history.name).to eq('Production Site')
      expect(history.history_user_id).to eq(user.id)
      expect(history.history_started_at).to be_present
      expect(history.history_ended_at).to be_nil
      
      website.update!(name: 'Updated Site', history_user_id: user.id)
      
      expect(website.histories.count).to eq(2)
      
      old_history = website.histories.where.not(history_ended_at: nil).first
      expect(old_history.name).to eq('Production Site')
      expect(old_history.history_ended_at).to be_present
      
      current_history = website.histories.current.first
      expect(current_history.name).to eq('Updated Site')
      expect(current_history.history_ended_at).to be_nil
    end
    
    it 'supports associations on history models' do
      website = Website.create!(name: 'Deploy Test Site', history_user_id: 1)
      history = website.histories.first
      
      deploy = Deploy.create!(
        website_history_id: history.id,
        status: 'pending'
      )
      
      expect(history.deploys).to include(deploy)
      expect(deploy.website_history).to eq(history)
      
      expect(history.deploys.where(status: 'pending').count).to eq(1)
    end
    
    it 'handles Safe mode without requiring history_user_id after initial creation' do
      website = Website.create!(name: 'Safe Mode Test', history_user_id: 1)
      
      expect { website.update!(name: 'Updated Safe Mode Test') }.not_to raise_error
      
      expect(website.histories.count).to eq(2)
      
      current_history = website.histories.current.first
      expect(current_history.name).to eq('Updated Safe Mode Test')
      expect(current_history.history_user_id).to eq(1)
      
      website.update!(name: 'Another Update', history_user_id: nil)
      expect(website.histories.count).to eq(3)
      newest_history = website.histories.current.first
      expect(newest_history.history_user_id).to be_nil
    end
    
    it 'properly sets up delegated methods on history instances' do
      website = Website.create!(name: 'Method Delegation Test', history_user_id: 1)
      history = website.histories.first
      
      expect(history).to respond_to(:name)
      
      expect(history.name).to eq('Method Delegation Test')
    end
  end
  
  describe 'Rails after_initialize hook' do
    it 'sets up associations after Rails initialization' do
      expect(WebsiteHistory.reflect_on_association(:website)).to be_present
      expect(WebsiteHistory.reflect_on_association(:deploys)).to be_present
      
      website_association = WebsiteHistory.reflect_on_association(:website)
      expect(website_association.class_name).to eq('Website')
    end
  end
end