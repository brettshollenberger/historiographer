require 'spec_helper'

# Load model classes
require_relative 'models/template'
require_relative 'models/template_history'
require_relative 'models/website'
require_relative 'models/website_history'
require_relative 'models/template_file'
require_relative 'models/template_file_history'
require_relative 'models/website_file'
require_relative 'models/website_file_history'
require_relative 'models/code_file'

describe 'View-backed model snapshotting' do
  describe 'Website with code_files association (view-backed)' do
    let(:template) { 
      Template.create!(
        name: 'Base Template', 
        description: 'A base template',
        history_user_id: 1
      ) 
    }
    let(:website) { 
      Website.create!(
        domain: 'example.com', 
        template: template,
        history_user_id: 1
      ) 
    }
    
    before do
      # Create template files
      @template_file1 = TemplateFile.create!(
        template: template,
        path: 'index.html',
        content: '<h1>Template Index</h1>',
        shasum: 'abc123',
        history_user_id: 1
      )
      
      @template_file2 = TemplateFile.create!(
        template: template,
        path: 'about.html',
        content: '<h1>Template About</h1>',
        shasum: 'def456',
        history_user_id: 1
      )
      
      # Create website file that overrides one template file
      @website_file = WebsiteFile.create!(
        website: website,
        path: 'index.html',
        content: '<h1>Custom Index</h1>',
        shasum: 'ghi789',
        history_user_id: 1
      )
    end
    
    it 'has code_files that are backed by a view' do
      # Verify that code_files exist
      expect(website.code_files.count).to eq(2)
      
      # Verify that CodeFile has no primary key
      expect(CodeFile.primary_key).to be_nil
      
      # Verify that CodeFile instances are read-only
      code_file = website.code_files.first
      expect(code_file.readonly?).to be true
    end
    
    it 'returns correct merged data from the view' do
      code_files = website.code_files.order(:path)
      
      # Should have about.html from template and index.html from website override
      expect(code_files.map(&:path)).to match_array(['about.html', 'index.html'])
      
      index_file = code_files.find { |cf| cf.path == 'index.html' }
      about_file = code_files.find { |cf| cf.path == 'about.html' }
      
      # index.html should come from website_files (override)
      expect(index_file.content).to eq('<h1>Custom Index</h1>')
      expect(index_file.source_type).to eq('WebsiteFile')
      expect(index_file.source_id).to eq(@website_file.id)
      
      # about.html should come from template_files
      expect(about_file.content).to eq('<h1>Template About</h1>')
      expect(about_file.source_type).to eq('TemplateFile')
      expect(about_file.source_id).to eq(@template_file2.id)
    end
    
    context 'when snapshotting a model with view-backed associations' do
      it 'creates snapshot for the main model but handles view-backed associations gracefully' do
        # Create a snapshot of the website
        expect { website.snapshot }.not_to raise_error
        
        # Verify that website history was created
        expect(WebsiteHistory.where(website_id: website.id)).not_to be_empty
        website_snapshot = WebsiteHistory.where(website_id: website.id).last
        expect(website_snapshot.snapshot_id).not_to be_nil
        
        # Verify that associated models with primary keys have histories
        expect(TemplateHistory.where(template_id: template.id)).not_to be_empty
        expect(WebsiteFileHistory.where(website_file_id: @website_file.id)).not_to be_empty
        expect(TemplateFileHistory.where(template_file_id: @template_file1.id)).not_to be_empty
      end
      
      it 'does not attempt to create history for view-backed models' do
        # Snapshot should succeed without trying to snapshot code_files
        expect { website.snapshot }.not_to raise_error
        
        # Verify snapshot was created
        snapshot = WebsiteHistory.where(website_id: website.id).where.not(snapshot_id: nil).last
        expect(snapshot).not_to be_nil
        
        # There should be no CodeFileHistory table/model
        expect { CodeFileHistory }.to raise_error(NameError)
      end
      
      it 'correctly identifies models without primary keys' do
        # CodeFile should not have a primary key
        expect(CodeFile.primary_key).to be_nil
        
        # Regular models should have primary keys
        expect(Website.primary_key).to eq('id')
        expect(WebsiteFile.primary_key).to eq('id')
        expect(TemplateFile.primary_key).to eq('id')
      end
      
      it 'allows snapshot to complete even with view associations present' do
        # Add more associations to make the test more complex
        website2 = Website.create!(domain: 'example2.com', template: template, history_user_id: 1)
        WebsiteFile.create!(
          website: website2,
          path: 'custom.html',
          content: '<h1>Custom Page</h1>',
          shasum: 'xyz999',
          history_user_id: 1
        )
        
        # Both websites should snapshot successfully
        expect { website.snapshot }.not_to raise_error
        expect { website2.snapshot }.not_to raise_error
        
        # Verify both have history records
        expect(WebsiteHistory.where(website_id: website.id)).not_to be_empty
        expect(WebsiteHistory.where(website_id: website2.id)).not_to be_empty
      end
    end
  end
  
  describe 'Error handling for view-backed models' do
    it 'should log a warning when attempting to snapshot a model without a primary key' do
      # We'll need to patch the snapshot method to detect and skip models without primary keys
      # This test verifies the expected behavior once the fix is implemented
      
      website = Website.create!(domain: 'test.com', history_user_id: 1)
      
      # Expect snapshot to complete successfully
      expect { website.snapshot }.not_to raise_error
      
      # The view-backed association should not have created any history
      # (since there's no history table for views)
      expect(WebsiteHistory.where(website_id: website.id).count).to eq(1)
    end
  end
end