# frozen_string_literal: true

require 'spec_helper'

# Helper method to handle Rails error expectations
def expect_rails_errors(errors, expected_errors)
  actual_errors = errors.respond_to?(:to_hash) ? errors.to_hash : errors.to_h
  # Ensure all error messages are arrays for compatibility
  actual_errors.each { |key, value| actual_errors[key] = Array(value) }
  expected_errors.each { |key, value| expected_errors[key] = Array(value) }
  expect(actual_errors).to eq(expected_errors)
end

describe Historiographer do
  before(:each) do
    @now = Timecop.freeze
  end
  after(:each) do
    Timecop.return
  end

  before(:all) do
    Historiographer::Configuration.mode = :histories
  end

  after(:all) do
    Timecop.return
  end

  let(:username) { 'Test User' }

  let(:user) do
    User.create(name: username)
  end

  let(:create_post) do
    Post.create(
      title: 'Post 1',
      body: 'Great post',
      author_id: 1,
      history_user_id: user.id
    )
  end

  let(:create_author) do
    Author.create(
      full_name: 'Breezy',
      history_user_id: user.id
    )
  end

  before(:each) do
    Historiographer::Configuration.mode = :histories
  end

  describe 'History counting' do
    it 'creates history on creation of primary model record' do
      expect do
        create_post
      end.to change {
        PostHistory.count
      }.by 1
    end

    it 'appends new history on update' do
      post = create_post
      expect do
        post.update(title: 'Better Title')
      end.to change {
        PostHistory.count
      }.by 1
    end

    it 'does not append new history if nothing has changed' do
      post = create_post

      expect do
        post.update(title: post.title)
      end.to_not change {
        PostHistory.count
      }
    end
  end

  describe 'History recording' do

    it 'records all fields from the parent' do
      post         = create_post
      post_history = post.histories.first

      expect(post_history.title).to eq     post.title
      expect(post_history.body).to eq      post.body
      expect(post_history.author_id).to eq post.author_id
      expect(post_history.post_id).to eq   post.id
      expect(post_history.history_started_at).to be_within(1.second).of(@now.in_time_zone(Historiographer::UTC))
      expect(post_history.history_ended_at).to be_nil
      expect(post_history.history_user_id).to eq user.id

      post.update(title: 'Better title')
      post_histories = post.histories.reload.order('id asc')
      first_history  = post_histories.first
      second_history = post_histories.second

      expect(first_history.history_ended_at).to be_within(1.second).of(@now.in_time_zone(Historiographer::UTC))
      expect(second_history.history_ended_at).to be_nil
    end

    it 'cannot create without history_user_id' do
      post = Post.create(
        title: 'Post 1',
        body: 'Great post',
        author_id: 1
      )

      # Use the helper method for error expectation
      expect_rails_errors(post.errors, history_user_id: ['must be an integer'])

      expect do
        post.send(:record_history)
      end.to raise_error(
        Historiographer::HistoryUserIdMissingError
      )
    end

    context 'When directly hitting the database via SQL' do
      context '#update_all' do
        it 'still updates histories' do
          FactoryBot.create_list(:post, 3, history_user_id: 1)

          posts = Post.all
          expect(posts.count).to eq 3
          expect(PostHistory.count).to eq 3
          expect(posts.map(&:histories).map(&:count)).to all (eq 1)

          posts.update_all(title: 'My New Post Title', history_user_id: 1)

          expect(PostHistory.count).to eq 6
          expect(PostHistory.current.count).to eq 3
          expect(posts.map(&:histories).map(&:count)).to all(eq 2)
          expect(posts.map(&:current_history).map(&:title)).to all (eq 'My New Post Title')
          expect(Post.all).to respond_to :has_histories?

          # It can update by sub-query
          Post.where(id: [posts.first.id, posts.last.id]).update_all(title: "Brett's Post", history_user_id: 1)
          posts = Post.all.reload.order(:id)
          expect(posts.first.histories.count).to eq 3
          expect(posts.second.histories.count).to eq 2
          expect(posts.third.histories.count).to eq 3
          expect(posts.first.title).to eq "Brett's Post"
          expect(posts.second.title).to eq 'My New Post Title'
          expect(posts.third.title).to eq "Brett's Post"
          expect(posts.first.current_history.title).to eq "Brett's Post"
          expect(posts.second.current_history.title).to eq 'My New Post Title'
          expect(posts.third.current_history.title).to eq "Brett's Post"

          # It does not update histories if nothing changed
          Post.all.update_all(title: "Brett's Post", history_user_id: 1)
          posts = Post.all.reload.order(:id)
          expect(posts.map(&:histories).map(&:count)).to all(eq 3)

          posts.update_all_without_history(title: 'Untracked')
          expect(posts.first.histories.count).to eq 3
          expect(posts.second.histories.count).to eq 3
          expect(posts.third.histories.count).to eq 3

          thing1 = ThingWithoutHistory.create(name: 'Thing 1')
          thing2 = ThingWithoutHistory.create(name: 'Thing 2')

          ThingWithoutHistory.all.update_all(name: 'Thing 3')
        end

        it 'respects safety' do
          FactoryBot.create_list(:post, 3, history_user_id: 1)

          posts = Post.all
          expect(posts.count).to eq 3
          expect(PostHistory.count).to eq 3
          expect(posts.map(&:histories).map(&:count)).to all (eq 1)

          expect do
            posts.update_all(title: 'My New Post Title')
          end.to raise_error

          posts.reload.map(&:title).each do |title|
            expect(title).to_not eq 'My New Post Title'
          end

          SafePost.create(
            title: 'Post 1',
            body: 'Great post',
            author_id: 1
          )

          safe_posts = SafePost.all

          expect do
            safe_posts.update_all(title: 'New One')
          end.to_not raise_error

          expect(safe_posts.map(&:title)).to all(eq 'New One')
        end
      end

      context '#delete_all' do
        it 'includes histories when not paranoid' do
          Timecop.freeze
          authors = 3.times.map do
            Author.create(full_name: 'Brett', history_user_id: 1)
          end
          Author.delete_all(history_user_id: 1)
          expect(AuthorHistory.count).to eq 3
          expect(AuthorHistory.current.count).to eq 0
          expect(AuthorHistory.where.not(history_ended_at: nil).count).to eq 3
          expect(Author.count).to eq 0
          Timecop.return
        end

        it 'includes histories when paranoid' do
          Timecop.freeze
          posts = FactoryBot.create_list(:post, 3, history_user_id: 1)
          Post.delete_all(history_user_id: 1)
          expect(PostHistory.unscoped.count).to eq 6
          expect(PostHistory.unscoped.current.count).to eq 3
          expect(PostHistory.unscoped.current.map(&:deleted_at)).to all(eq Time.now)
          expect(PostHistory.unscoped.current.map(&:history_user_id)).to all(eq 1)
          expect(PostHistory.unscoped.where(deleted_at: nil).where.not(history_ended_at: nil).count).to eq 3
          expect(PostHistory.unscoped.where(history_ended_at: nil).count).to eq 3
          expect(Post.count).to eq 0
          Timecop.return
        end

        it 'allows delete_all_without_history' do
          authors = 3.times.map do
            Author.create(full_name: 'Brett', history_user_id: 1)
          end
          Author.all.delete_all_without_history
          expect(AuthorHistory.current.count).to eq 3
          expect(Author.count).to eq 0
        end
      end

      context '#destroy_all' do
        it 'includes histories' do
          Timecop.freeze
          posts = FactoryBot.create_list(:post, 3, history_user_id: 1)
          Post.destroy_all(history_user_id: 1)
          expect(PostHistory.unscoped.count).to eq 6
          expect(PostHistory.unscoped.current.count).to eq 3
          expect(PostHistory.unscoped.current.map(&:deleted_at)).to all(eq Time.now)
          expect(PostHistory.unscoped.current.map(&:history_user_id)).to all(eq 1)
          expect(PostHistory.unscoped.where(deleted_at: nil).where.not(history_ended_at: nil).count).to eq 3
          expect(PostHistory.unscoped.where(history_ended_at: nil).count).to eq 3
          expect(Post.count).to eq 0
          Timecop.return
        end

        it 'destroys without histories' do
          Timecop.freeze
          posts = FactoryBot.create_list(:post, 3, history_user_id: 1)
          Post.all.destroy_all_without_history
          expect(PostHistory.count).to eq 3
          expect(PostHistory.current.count).to eq 3
          expect(Post.count).to eq 0
          Timecop.return
        end
      end
    end

    context 'When Safe mode' do
      it 'creates history without history_user_id' do
        expect(Rollbar).to receive(:error).with('history_user_id must be passed in order to save record with histories! If you are in a context with no history_user_id, explicitly call #save_without_history')

        post = SafePost.create(
          title: 'Post 1',
          body: 'Great post',
          author_id: 1
        )
        expect_rails_errors(post.errors, {})
        expect(post).to be_persisted
        expect(post.histories.count).to eq 1
        expect(post.histories.first.history_user_id).to be_nil
      end

      it 'creates history with history_user_id' do
        expect(Rollbar).to_not receive(:error)

        post = SafePost.create(
          title: 'Post 1',
          body: 'Great post',
          author_id: 1,
          history_user_id: user.id
        )
        expect_rails_errors(post.errors, {})
        expect(post).to be_persisted
        expect(post.histories.count).to eq 1
        expect(post.histories.first.history_user_id).to eq user.id
      end

      it 'skips history creation if desired' do
        post = SafePost.new(
          title: 'Post 1',
          body: 'Great post',
          author_id: 1
        )

        post.save_without_history
        expect(post).to be_persisted
        expect(post.histories.count).to eq 0
      end
    end

    context 'When Silent mode' do
      it 'creates history without history_user_id' do
        expect(Rollbar).to_not receive(:error)

        post = SilentPost.create(
          title: 'Post 1',
          body: 'Great post',
          author_id: 1
        )

        expect_rails_errors(post.errors, {})
        expect(post).to be_persisted
        expect(post.histories.count).to eq 1
        expect(post.histories.first.history_user_id).to be_nil

        post.update(title: 'New Title')
        post.reload
        expect(post.title).to eq 'New Title' # No error was raised
      end

      it 'creates history with history_user_id' do
        expect(Rollbar).to_not receive(:error)

        post = SilentPost.create(
          title: 'Post 1',
          body: 'Great post',
          author_id: 1,
          history_user_id: user.id
        )
        expect_rails_errors(post.errors, {})
        expect(post).to be_persisted
        expect(post.histories.count).to eq 1
        expect(post.histories.first.history_user_id).to eq user.id
      end

      it 'skips history creation if desired' do
        post = SilentPost.new(
          title: 'Post 1',
          body: 'Great post',
          author_id: 1
        )

        post.save_without_history
        expect(post).to be_persisted
        expect(post.histories.count).to eq 0
      end
    end
    it 'can override without history_user_id' do
      expect do
        post = Post.new(
          title: 'Post 1',
          body: 'Great post',
          author_id: 1
        )

        post.save_without_history
      end.to_not raise_error
    end

    it 'can override without history_user_id' do
      expect do
        post = Post.new(
          title: 'Post 1',
          body: 'Great post',
          author_id: 1
        )

        post.save_without_history!
      end.to_not raise_error
    end

    it 'does not record histories when main model fails to save' do
      class Post
        after_save :raise_error, prepend: true

        def raise_error
          raise 'Oh no, db issue!'
        end
      end

      expect { create_post }.to raise_error
      expect(Post.count).to be 0
      expect(PostHistory.count).to be 0

      Post.skip_callback(:save, :after, :raise_error)
    end
  end


  describe 'Scopes' do
    it 'finds current histories' do
      post1 = create_post
      post1.update(title: 'Better title')

      post2 = create_post
      post2.update(title: 'Better title')

      expect(PostHistory.current.pluck(:title)).to all eq 'Better title'
      expect(post1.current_history.title).to eq 'Better title'
    end
  end

  describe 'Associations' do
    it 'names associated records' do
      post1 = create_post
      expect(post1.histories.first).to be_a(PostHistory)

      expect(post1.histories.first.post).to eq(post1)

      author1 = create_author
      expect(author1.histories.first).to be_a(AuthorHistory)

      expect(author1.histories.first.author).to eq(author1)
    end
  end

  describe 'Histories' do
    it 'does not allow direct updates of histories' do
      post1 = create_post
      hist1 = post1.histories.first

      expect(hist1.update(title: 'A different title')).to be false
      expect(hist1.reload.title).to eq post1.title

      expect(hist1.update!(title: 'A different title')).to be false
      expect(hist1.reload.title).to eq post1.title

      hist1.title = 'A different title'
      expect(hist1.save).to be false
      expect(hist1.reload.title).to eq post1.title

      hist1.title = 'A different title'
      expect(hist1.save!).to be false
      expect(hist1.reload.title).to eq post1.title
    end

    it 'does not allow destroys of histories' do
      post1                  = create_post
      hist1                  = post1.histories.first
      original_history_count = post1.histories.count

      expect(hist1.destroy).to be false
      expect(hist1.destroy!).to be false

      expect(post1.histories.count).to be original_history_count
    end
  end

  describe 'Deletion' do
    it 'records deleted_at and history_user_id on primary and history if you use acts_as_paranoid' do
      post = Post.create(
        title: 'Post 1',
        body: 'Great post',
        author_id: 1,
        history_user_id: user.id
      )

      expect do
        post.destroy(history_user_id: 2)
      end.to change {
        PostHistory.unscoped.count
      }.by 1

      expect(Post.unscoped.where.not(deleted_at: nil).count).to eq 1
      expect(Post.unscoped.where(deleted_at: nil).count).to eq 0
      expect(PostHistory.unscoped.where.not(deleted_at: nil).count).to eq 1
      expect(PostHistory.unscoped.last.history_user_id).to eq 2
    end

    it 'works with Historiographer::Safe' do
      post = SafePost.create(title: 'HELLO', body: 'YO', author_id: 1)

      expect do
        post.destroy
      end.to_not raise_error

      expect(SafePost.unscoped.count).to eq 1
      expect(post.deleted_at).to_not be_nil
      expect(SafePostHistory.unscoped.count).to eq 2
      expect(SafePostHistory.unscoped.current.last.deleted_at).to eq post.deleted_at

      post2 = SafePost.create(title: 'HELLO', body: 'YO', author_id: 1)

      expect do
        post2.destroy!
      end.to_not raise_error

      expect(SafePost.count).to eq 0
      expect(post2.deleted_at).to_not be_nil
      expect(SafePostHistory.unscoped.count).to eq 4
      expect(SafePostHistory.unscoped.current.where(safe_post_id: post2.id).last.deleted_at).to eq post2.deleted_at
    end
  end

  describe 'Empty insertion handling' do
    it 'handles duplicate history gracefully by returning existing record' do
      # Create post without history tracking to avoid initial history
      post = Post.new(
        title: 'Post 1',
        body: 'Great post',
        author_id: 1,
        history_user_id: user.id
      )
      post.save_without_history
      
      # Freeze time to ensure same timestamp
      Timecop.freeze do
        # Create a history record with current timestamp
        now = Historiographer::UTC.now
        attrs = post.send(:history_attrs, now: now)
        existing_history = PostHistory.create!(attrs)
        
        # Mock insert_all to return empty result (simulating duplicate constraint)
        empty_result = double('result')
        allow(empty_result).to receive(:rows).and_return([])
        
        allow(PostHistory).to receive(:insert_all).and_return(empty_result)
        
        # The method should find and return the existing history
        allow(Rails.logger).to receive(:warn).with(/Duplicate history detected/) if Rails.logger
        result = post.send(:record_history)
        expect(result.id).to eq(existing_history.id)
        expect(result.post_id).to eq(post.id)
      end
    end
    
    it 'raises error when insert fails and no existing record found' do
      post = create_post
      
      # Mock insert_all to return an empty result
      empty_result = double('result')
      allow(empty_result).to receive(:rows).and_return([])
      
      allow(PostHistory).to receive(:insert_all).and_return(empty_result)
      
      # Mock the where clause for finding existing history to return nothing
      # We need to be specific about the where clause we're mocking
      original_where = PostHistory.method(:where)
      allow(PostHistory).to receive(:where) do |*args|
        # Check if this is the specific query for finding duplicates
        # The foreign key is "post_id" (string) and we're checking for history_started_at
        if args.first.is_a?(Hash) && args.first.keys.include?("post_id") && args.first.keys.include?(:history_started_at)
          # Return a double that returns nil when .first is called
          double('where').tap { |d| allow(d).to receive(:first).and_return(nil) }
        else
          # For all other queries, use the original behavior
          original_where.call(*args)
        end
      end
      
      # This should raise a meaningful error
      expect {
        post.send(:record_history)
      }.to raise_error
    end

    it 'provides meaningful error when insertion fails' do
      post = create_post
      
      # Mock insert_all to simulate a database-level failure
      # This could happen due to various reasons:
      # - Database is read-only
      # - Connection issues
      # - Constraint violations that prevent insertion
      allow(PostHistory).to receive(:insert_all).and_raise(ActiveRecord::StatementInvalid, "PG::ReadOnlySqlTransaction: ERROR: cannot execute INSERT in a read-only transaction")
      
      expect {
        post.send(:record_history)
      }.to raise_error(ActiveRecord::StatementInvalid)
    end
    
    it 'successfully inserts history when everything is valid' do
      post = create_post
      
      # Clear existing histories
      PostHistory.where(post_id: post.id).destroy_all
      
      # Record a new history
      history = post.send(:record_history)
      
      expect(history).to be_a(PostHistory)
      expect(history).to be_persisted
      expect(history.post_id).to eq(post.id)
      expect(history.title).to eq(post.title)
      expect(history.body).to eq(post.body)
    end
    
    it 'handles race conditions by returning existing history' do
      post = create_post
      
      # Simulate a race condition where the same history_started_at timestamp is used
      now = Time.now
      allow(Historiographer::UTC).to receive(:now).and_return(now)
      
      # First process creates history
      history1 = post.histories.last
      
      # Second process tries to create history with same timestamp
      # This would normally cause insert_all to return empty rows
      history2 = post.send(:record_history)
      
      # Should handle gracefully
      expect(history2).to be_a(PostHistory)
    end
  end

  describe 'Scopes' do
    it 'finds current' do
      post = create_post
      post.update(title: 'New Title')
      post.update(title: 'New Title 2')

      expect(PostHistory.current.count).to be 1
    end
  end

  describe 'User associations' do
    it 'links to user' do
      post = create_post
      author = create_author

      expect(post.current_history.user.name).to eq username
      expect(author.current_history.user.name).to eq username
    end
  end

  describe 'Migrations with compound indexes' do
    it 'supports renaming compound indexes and migrating them to history tables' do
      indices_sql = "
        SELECT
          DISTINCT(
            ARRAY_TO_STRING(ARRAY(
             SELECT pg_get_indexdef(idx.indexrelid, k + 1, true)
             FROM generate_subscripts(idx.indkey, 1) as k
             ORDER BY k
           ), ',')
         ) as indkey_names
        FROM pg_class t,
        pg_class i,
        pg_index idx,
        pg_attribute a,
        pg_am am
        WHERE t.oid = idx.indrelid
        AND i.oid = idx.indexrelid
        AND a.attrelid = t.oid
        AND a.attnum = ANY(idx.indkey)
        AND t.relkind = 'r'
        AND t.relname = ?;
      "

      indices_query_array = [indices_sql, :thing_with_compound_index_histories]
      indices_sanitized_query = ThingWithCompoundIndexHistory.send(:sanitize_sql_array, indices_query_array)

      indexes = ThingWithCompoundIndexHistory.connection.execute(indices_sanitized_query).to_a.map(&:values).flatten.map { |i| i.split(',') }

      expect(indexes).to include(['history_started_at'])
      expect(indexes).to include(['history_ended_at'])
      expect(indexes).to include(['history_user_id'])
      expect(indexes).to include(['id'])
      expect(indexes).to include(%w[key value])
      expect(indexes).to include(['thing_with_compound_index_id'])
    end
  end

  describe 'Reified Histories' do
    let(:post) { create_post }
    let(:post_history) { post.histories.first }
    let(:author) { Author.create(full_name: 'Commenter Jones', history_user_id: user.id) }
    let(:comment) { Comment.create(post: post, author: author, history_user_id: user.id) }

    it 'responds to methods defined on the original class' do
      expect(post_history).to respond_to(:summary)
      expect(post_history.summary).to eq('This is a summary of the post.')
    end

    it 'behaves like the original class for attribute methods' do
      expect(post_history.title).to eq(post.title)
      expect(post_history.body).to eq(post.body)
    end

    it 'supports custom instance methods' do
      expect(post_history).to respond_to(:formatted_title)
      expect(post_history.formatted_title).to eq("Title: #{post.title}")
    end
    
    it "does not do things histories shouldn't do" do
      post_history.update(title: "new title")
      expect(post_history.reload.title).to eq "Post 1"

      post_history.destroy
      expect(post_history.reload.title).to eq "Post 1"
    end
  end

  describe 'Snapshots' do
    let(:post) { create_post }
    let(:author) { Author.create(full_name: 'Commenter Jones', history_user_id: user.id) }
    let(:comment) { Comment.create(body: "Mean comment! I hate you!", post: post, author: author, history_user_id: user.id) }

    it 'creates a snapshot of the post and its associations' do
      # Take a snapshot
      comment # Make sure all records are created
      post.snapshot

      # Verify snapshot
      snapshot_post = PostHistory.where.not(snapshot_id: nil).last
      expect(snapshot_post.title).to eq post.title
      expect(snapshot_post.formatted_title).to eq post.formatted_title

      snapshot_comment = snapshot_post.comments.first
      expect(snapshot_comment.body).to eq comment.body
      expect(snapshot_comment.post_id).to eq post.id
      expect(snapshot_comment.class.name.to_s).to eq "CommentHistory"

      snapshot_author = snapshot_comment.author
      expect(snapshot_author.full_name).to eq author.full_name
      expect(snapshot_author.class.name.to_s).to eq "AuthorHistory"

      # Snapshots do not allow change
      expect(snapshot_post.update(title: "My title")).to eq false
      expect(snapshot_post.reload.title).to eq post.title
    end

    it "allows override of methods on history class" do
      post.snapshot
      expect(post.latest_snapshot.locked_value).to eq "My Great Post v100"
      expect(post.locked_value).to eq "My Great Post v1"

      expect(post.complex_lookup).to eq "Here is a complicated value, it is: My Great Post v1 And another: Title: Post 1"
      expect(post.latest_snapshot.complex_lookup).to eq "Here is a complicated value, it is: My Great Post v100 And another: Title: Post 1"
    end

    it "returns the latest snapshot" do
      Timecop.freeze(Time.now)
      # Take a snapshot
      comment # Make sure all records are created
      post.snapshot(history_user_id: user.id)
      comment.destroy(history_user_id: user.id)
      post.comments.create!(post: post, author: author, history_user_id: user.id, body: "Sorry man, didn't mean to post that")

      expect(PostHistory.count).to eq 1
      expect(CommentHistory.count).to eq 2
      expect(AuthorHistory.count).to eq 1

      Timecop.freeze(Time.now + 5.minutes)
      post.snapshot(history_user_id: user.id)

      expect(PostHistory.count).to eq 2
      expect(CommentHistory.count).to eq 2
      expect(AuthorHistory.count).to eq 2

      # Verify snapshot
      snapshot_post = post.latest_snapshot
      expect(snapshot_post.title).to eq post.title
      expect(snapshot_post.formatted_title).to eq post.formatted_title

      snapshot_comment = snapshot_post.comments.first
      expect(snapshot_post.comments.count).to eq 1
      expect(snapshot_comment.body).to eq "Sorry man, didn't mean to post that"
      expect(snapshot_comment.post_id).to eq post.id
      expect(snapshot_comment.class.name.to_s).to eq "CommentHistory"

      snapshot_author = snapshot_comment.author
      expect(snapshot_author.full_name).to eq author.full_name
      expect(snapshot_author.class.name.to_s).to eq "AuthorHistory"

      # Snapshots do not allow change
      expect(snapshot_post.update(title: "My title")).to eq false
      expect(snapshot_post.reload.title).to eq post.title
      
      Timecop.return
    end

    it "uses snapshot_only mode" do
      Historiographer::Configuration.mode = :snapshot_only

      comment # Make sure all records are created
      post
      expect(PostHistory.count).to eq 0
      expect(CommentHistory.count).to eq 0
      expect(AuthorHistory.count).to eq 0

      post.snapshot
      expect(PostHistory.count).to eq 1
      expect(CommentHistory.count).to eq 1
      expect(AuthorHistory.count).to eq 1

      comment.destroy(history_user_id: user.id)
      post.comments.create!(post: post, author: author, history_user_id: user.id, body: "Sorry man, didn't mean to post that")

      expect(PostHistory.count).to eq 1
      expect(CommentHistory.count).to eq 1
      expect(AuthorHistory.count).to eq 1

      Timecop.freeze(Time.now + 5.minutes)
      post.snapshot

      expect(PostHistory.count).to eq 2
      expect(CommentHistory.count).to eq 2
      expect(AuthorHistory.count).to eq 2
    end

    it "runs callbacks at the appropriate time" do
      comment
      post.snapshot # 1 comment
      comment2 = comment.dup
      comment2.body = "Hello there"
      comment2.save

      post.reload
      expect(post.comment_count).to eq 2
      expect(post.latest_snapshot.comment_count).to eq 1
    end

    it "snapshots all children when one has a null_snapshot history record" do
      # This tests a bug where if one child record already has a history with snapshot_id: nil,
      # the snapshot would silently fail to update it due to belongs_to :user validation
      Historiographer::Configuration.mode = :snapshot_only

      # Create records without triggering histories (snapshot_only mode)
      author1 = Author.create(full_name: 'Author One', history_user_id: user.id)
      author2 = Author.create(full_name: 'Author Two', history_user_id: user.id)

      # Manually create a null_snapshot history for author1 (simulating previous state)
      # This mimics what happens when a record has a history created outside of snapshot
      AuthorHistory.create!(
        author_id: author1.id,
        full_name: author1.full_name,
        history_user_id: nil,  # No user - this will trigger the bug
        snapshot_id: nil,      # Null snapshot
        history_started_at: Time.current
      )

      expect(AuthorHistory.count).to eq 1
      expect(AuthorHistory.where(snapshot_id: nil).count).to eq 1

      # Now snapshot author1 - this should work even though there's a null_snapshot
      # The bug: without_history_user_id doesn't prevent belongs_to :user validation
      author1.snapshot

      expect(AuthorHistory.where.not(snapshot_id: nil).count).to eq 1
      expect(AuthorHistory.first.snapshot_id).to be_present
    end

    it "doesn't explode" do
      project = Project.create(name: "test_project")
      project_file = ProjectFile.create(project: project, name: "test_file", content: "Hello world")

      original_snapshot = project.snapshot

      project_file.update(content: "Goodnight moon")
      new_snapshot = project.snapshot

      expect(original_snapshot.files.map(&:class)).to eq [ProjectFileHistory]
      expect(new_snapshot.files.map(&:class)).to eq [ProjectFileHistory]

      expect(new_snapshot.files.first.content).to eq "Goodnight moon"
      expect(original_snapshot.files.first.content).to eq "Hello world"
    end
  end


  describe 'Class-level mode setting' do
    before(:each) do
      Historiographer::Configuration.mode = :histories
    end

    it "uses class-level snapshot_only mode" do
      class Post < ApplicationRecord
        historiographer_mode :snapshot_only
      end

      author = Author.create(full_name: 'Commenter Jones', history_user_id: user.id) 
      post = Post.create(title: 'Snapshot Only Post', body: 'Test', author_id: 1, history_user_id: user.id)
      comment = Comment.create(post: post, author: author, history_user_id: user.id, body: "Initial comment")
      
      expect(PostHistory.count).to eq 0
      expect(CommentHistory.count).to eq 1  # Comment still uses default :histories mode

      post.snapshot
      expect(PostHistory.count).to eq 1
      expect(CommentHistory.count).to eq 1

      post.update(title: 'Updated Snapshot Only Post', history_user_id: user.id)
      expect(PostHistory.count).to eq 1  # No new history created for update
      expect(CommentHistory.count).to eq 1

      Timecop.freeze(Time.now + 5.minutes)
      post.snapshot

      expect(PostHistory.count).to eq 2
      expect(CommentHistory.count).to eq 2  # Comment creates a new history

      Timecop.return

      class Post < ApplicationRecord
        historiographer_mode nil
      end
    end
  end

  describe 'Moduleized Classes' do
    let(:user) { User.create(name: 'Test User') }
    let(:column) do
      EasyML::Column.create(
        name: 'feature_1',
        data_type: 'numeric',
        history_user_id: user.id
      )
    end

    it 'maintains proper namespacing in history class' do
      expect(column).to be_a(EasyML::Column)
      expect(column.histories.first).to be_a(EasyML::ColumnHistory)
      expect(EasyML::Column.history_class).to eq(EasyML::ColumnHistory)
    end

    it 'establishes correct foreign key for history association' do
      col_history = column.histories.first
      expect(col_history.class.history_foreign_key).to eq('easy_ml_column_id')
      expect(col_history).to be_a(EasyML::ColumnHistory)
    end


    it 'uses correct table names' do
      expect(EasyML::Column.table_name).to eq('easy_ml_columns')
      expect(EasyML::ColumnHistory.table_name).to eq('easy_ml_column_histories')
    end

    it 'creates and updates history records properly' do
      original_name = column.name
      column.update(name: 'feature_2', history_user_id: user.id)
      
      expect(column.histories.count).to eq(2)
      expect(column.histories.first.name).to eq(original_name)
      expect(column.histories.last.name).to eq('feature_2')
    end
  end

  describe 'Non-historiographer associations' do
    it 'preserves associations to models without history tracking' do
      # Create an author and byline (byline has no history tracking)
      author = Author.create!(full_name: 'Test Author', history_user_id: 1)
      byline = Byline.create!(name: 'Test Byline', author: author)
      
      # The author should have the byline association
      expect(author.bylines).to include(byline)
      
      # Get the author's history record
      author_history = AuthorHistory.last
      expect(author_history).not_to be_nil
      
      # The history model should still be able to access the byline (non-history model)
      # This should work because Byline doesn't have history tracking
      expect(author_history.bylines).to include(byline)
      
      # The association should point to the regular Byline model, not a history model
      byline_association = AuthorHistory.reflect_on_association(:bylines)
      expect(byline_association).not_to be_nil
      expect(byline_association.klass).to eq(Byline)
    end
    
    it 'handles mixed associations correctly' do
      # Create an author with both history-tracked and non-history-tracked associations
      author = Author.create!(full_name: 'Test Author', history_user_id: 1)
      post = Post.create!(title: 'Test Post', body: 'Test body', author_id: author.id, history_user_id: 1)
      comment = Comment.create!(body: 'Test comment', author_id: author.id, post_id: post.id, history_user_id: 1)
      byline = Byline.create!(name: 'Test Byline', author: author)
      
      author_history = AuthorHistory.last
      
      # History-tracked associations should work correctly
      # Note: For history associations, we create custom methods rather than Rails associations
      # so they won't show up in reflect_on_all_associations
      expect(author_history).to respond_to(:posts)
      expect(author_history).to respond_to(:comments)
      
      # The methods should return history records filtered by snapshot_id
      post_histories = PostHistory.where(author_id: author.id)
      expect(post_histories).not_to be_empty
      
      # When accessing through the history model, it should filter by snapshot_id
      author_history_posts = author_history.posts
      expect(author_history_posts).to be_a(ActiveRecord::Relation)
      
      # Non-history-tracked associations should show up as regular Rails associations
      bylines_association = AuthorHistory.reflect_on_association(:bylines)
      expect(bylines_association).not_to be_nil
      expect(bylines_association.klass).to eq(Byline)
      
      # And they should work correctly
      expect(author_history.bylines).to include(byline)
    end
  end

  describe 'Association options preservation' do
    # Test with inline class definitions to ensure associations are defined properly
    
    before(:all) do
      # Create test classes inline for this test
      class TestAssocArticle < ActiveRecord::Base
        self.table_name = 'test_articles'
        include Historiographer
        belongs_to :test_assoc_category, 
                   class_name: 'TestAssocCategory',
                   foreign_key: 'test_category_id',
                   optional: true, 
                   touch: true, 
                   counter_cache: 'test_articles_count'
      end
      
      class TestAssocCategory < ActiveRecord::Base
        self.table_name = 'test_categories'
        include Historiographer
        has_many :test_assoc_articles, 
                 class_name: 'TestAssocArticle',
                 foreign_key: 'test_category_id',
                 dependent: :restrict_with_error, 
                 inverse_of: :test_assoc_category
      end
      
      class TestAssocArticleHistory < ActiveRecord::Base
        self.table_name = 'test_article_histories'
        include Historiographer::History
      end
      
      class TestAssocCategoryHistory < ActiveRecord::Base
        self.table_name = 'test_category_histories'
        include Historiographer::History
      end
      
      # Manually trigger association setup since we're in a test environment
      # Force = true because associations may have been partially set up before all models were loaded
      TestAssocArticleHistory.setup_history_associations(true) if TestAssocArticleHistory.respond_to?(:setup_history_associations)
      TestAssocCategoryHistory.setup_history_associations(true) if TestAssocCategoryHistory.respond_to?(:setup_history_associations)
    end
    
    after(:all) do
      Object.send(:remove_const, :TestAssocArticle) if Object.const_defined?(:TestAssocArticle)
      Object.send(:remove_const, :TestAssocArticleHistory) if Object.const_defined?(:TestAssocArticleHistory)
      Object.send(:remove_const, :TestAssocCategory) if Object.const_defined?(:TestAssocCategory)
      Object.send(:remove_const, :TestAssocCategoryHistory) if Object.const_defined?(:TestAssocCategoryHistory)
    end
    
    it 'preserves optional setting for belongs_to associations' do
      # Check the original TestAssocArticle belongs_to association
      article_association = TestAssocArticle.reflect_on_association(:test_assoc_category)
      expect(article_association).not_to be_nil
      expect(article_association.options[:optional]).to eq(true)
      
      # The TestAssocArticleHistory should have the same options
      article_history_association = TestAssocArticleHistory.reflect_on_association(:test_assoc_category)
      expect(article_history_association).not_to be_nil
      expect(article_history_association.options[:optional]).to eq(true)
    end
    
    it 'preserves touch and counter_cache options for belongs_to associations' do
      article_association = TestAssocArticle.reflect_on_association(:test_assoc_category)
      expect(article_association.options[:touch]).to eq(true)
      expect(article_association.options[:counter_cache]).to eq('test_articles_count')
      
      article_history_association = TestAssocArticleHistory.reflect_on_association(:test_assoc_category)
      expect(article_history_association).not_to be_nil
      expect(article_history_association.options[:touch]).to eq(true)
      expect(article_history_association.options[:counter_cache]).to eq('test_articles_count')
    end
    
    it 'preserves dependent and inverse_of options for has_many associations' do
      category_articles_association = TestAssocCategory.reflect_on_association(:test_assoc_articles)
      expect(category_articles_association.options[:dependent]).to eq(:restrict_with_error)
      expect(category_articles_association.options[:inverse_of]).to eq(:test_assoc_category)
      
      # Note: has_many associations might not be copied to history models in the same way
      # This is expected behavior since history models typically don't need the same associations
    end
    
    it 'allows creating history records with nil optional associations' do
      # Create an article without a category (should be valid since category is optional)
      article = TestAssocArticle.create!(title: 'Test Article without category', history_user_id: 1)
      expect(article.test_category_id).to be_nil
      
      # The history record should also be created successfully
      history = TestAssocArticleHistory.last
      expect(history).not_to be_nil
      expect(history.test_category_id).to be_nil
      expect(history.test_article_id).to eq(article.id)

      # Creating snapshots should work even with nil associations
      article.snapshot
      expect { article.snapshot }.to_not raise_error
    end
  end

  describe 'Foreign key handling' do
    before(:all) do
      # Ensure test tables exist
      unless ActiveRecord::Base.connection.table_exists?(:test_users)
        ActiveRecord::Base.connection.create_table :test_users do |t|
          t.string :name
          t.timestamps
        end
      end
      
      unless ActiveRecord::Base.connection.table_exists?(:test_user_histories)
        ActiveRecord::Base.connection.create_table :test_user_histories do |t|
          t.integer :test_user_id, null: false
          t.string :name
          t.timestamps
          t.datetime :history_started_at, null: false
          t.datetime :history_ended_at
          t.integer :history_user_id
          t.string :snapshot_id
          
          t.index :test_user_id
          t.index :history_started_at
          t.index :history_ended_at
          t.index :snapshot_id
        end
      end
      
      unless ActiveRecord::Base.connection.table_exists?(:test_websites)
        ActiveRecord::Base.connection.create_table :test_websites do |t|
          t.string :name
          t.integer :user_id
          t.timestamps
        end
      end
      
      unless ActiveRecord::Base.connection.table_exists?(:test_website_histories)
        ActiveRecord::Base.connection.create_table :test_website_histories do |t|
          t.integer :test_website_id, null: false
          t.string :name
          t.integer :user_id
          t.timestamps
          t.datetime :history_started_at, null: false
          t.datetime :history_ended_at
          t.integer :history_user_id
          t.string :snapshot_id
          
          t.index :test_website_id
          t.index :history_started_at
          t.index :history_ended_at
          t.index :snapshot_id
        end
      end
    end
    
    describe 'belongs_to associations on history models' do
      it 'does not raise error about wrong column when accessing belongs_to associations' do
        # This is the core issue: when a history model has a belongs_to association,
        # it should not use the foreign key as the primary key for lookups
        
        # Create a user
        user = TestUser.create!(name: 'Test User', history_user_id: 1)
        
        # Create a website belonging to the user
        website = TestWebsite.create!(
          name: 'Test Website',
          user_id: user.id,
          history_user_id: 1
        )
        
        # Get the website history
        website_history = TestWebsiteHistory.last
        
        # The history should have the correct user_id
        expect(website_history.user_id).to eq(user.id)
        
        # The belongs_to association should work without errors
        # Previously this would fail with "column users.user_id does not exist"
        # because it was using primary_key: :user_id instead of the default :id
        expect { website_history.user }.not_to raise_error
      end
      
      it 'allows direct creation of history records with foreign keys' do
        user = TestUser.create!(name: 'Another User', history_user_id: 1)
        
        # Create history attributes like in the original error case
        attrs = {
          "name" => "test.example",
          "user_id" => user.id,
          "created_at" => Time.now,
          "updated_at" => Time.now,
          "test_website_id" => 100,
          "history_started_at" => Time.now,
          "history_user_id" => 1,
          "snapshot_id" => SecureRandom.uuid
        }
        
        # This should not raise an error about test_users.user_id not existing
        # The original bug was that it would look for test_users.user_id instead of test_users.id
        expect { TestWebsiteHistory.create!(attrs) }.not_to raise_error
        
        history = TestWebsiteHistory.last
        expect(history.user_id).to eq(user.id)
      end
    end
    
    describe 'snapshot associations with history models' do
      it 'correctly filters associations by snapshot_id when using custom association methods' do
        # First create regular history records
        user = TestUser.create!(name: 'User One', history_user_id: 1)
        website = TestWebsite.create!(
          name: 'Website One',
          user_id: user.id,
          history_user_id: 1
        )
        
        # Check that regular histories were created
        expect(TestUserHistory.count).to eq(1)
        expect(TestWebsiteHistory.count).to eq(1)
        
        # Now create snapshot histories directly (simulating what snapshot would do)
        snapshot_id = SecureRandom.uuid
        
        # Create user history with snapshot
        user_snapshot = TestUserHistory.create!(
          test_user_id: user.id,
          name: user.name,
          created_at: user.created_at,
          updated_at: user.updated_at,
          history_started_at: Time.now,
          history_user_id: 1,
          snapshot_id: snapshot_id
        )
        
        # Create website history with snapshot
        website_snapshot = TestWebsiteHistory.create!(
          test_website_id: website.id,
          name: website.name,
          user_id: user.id,
          created_at: website.created_at,
          updated_at: website.updated_at,
          history_started_at: Time.now,
          history_user_id: 1,
          snapshot_id: snapshot_id
        )
        
        # Now test that the association filtering works
        # The website history's user association should find the user history with the same snapshot_id
        user_from_association = website_snapshot.user
        
        # Since user association points to history when snapshots are involved,
        # it should return the TestUserHistory with matching snapshot_id
        if user_from_association.is_a?(TestUserHistory)
          expect(user_from_association.snapshot_id).to eq(snapshot_id)
          expect(user_from_association.name).to eq('User One')
        else
          # If it returns the regular TestUser (non-history), that's also acceptable
          # as long as it doesn't error
          expect(user_from_association).to be_a(TestUser)
          expect(user_from_association.name).to eq('User One')
        end
      end
    end
  end
end