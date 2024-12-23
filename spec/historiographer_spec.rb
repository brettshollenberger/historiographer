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

  describe 'Method stubbing' do
    it 'handles adding method appropriately' do
      post = PrivatePost.create(title: 'Post 1', body: "Hello", author_id: 1, history_user_id: 1)
      expect(post.formatted_title).to eq("Private — You cannot see!")
      
      allow_any_instance_of(PrivatePost).to receive(:formatted_title).and_return("New Title")
      expect(post.formatted_title).to eq("New Title")
      
      # Ensure history still works
      post.update(title: 'Updated Title', history_user_id: user.id)
      expect(post.histories.count).to eq(2)
      expect(post.histories.first.class).to eq(PrivatePostHistory)  # Verify correct history class
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
  end

  describe 'Single Table Inheritance' do
    let(:user) { User.create(name: 'Test User') }
    let(:private_post) do 
      PrivatePost.create(
        title: 'Private Post',
        body: 'Test',
        history_user_id: user.id,
        author_id: 1
      )
    end

    it 'maintains original class type on create' do
      post_history = private_post.histories.first
      expect(post_history.original_class).to eq(PrivatePost)
    end

    it 'maintains original class in history records' do
      post_history = private_post.histories.first
      expect(post_history.original_class).to eq(PrivatePost)
      expect(post_history.title).to eq('Private — You cannot see!')
    end

    it 'maintains original class behavior when updating' do
      private_post.update(title: 'Updated Private Post', history_user_id: user.id)
      new_history = private_post.histories.current&.first
      expect(new_history.original_class).to eq(PrivatePost)
      expect(new_history.title).to eq('Private — You cannot see!')
    end

    it 'maintains original class behavior when reifying' do
      private_post.update(title: 'Updated Private Post', history_user_id: user.id)
      old_history = private_post.histories.first
      reified = old_history
      expect(reified.title).to eq('Private — You cannot see!')
      expect(reified.original_class).to eq(PrivatePost)
    end
  end

  describe 'Single Table Inheritance with Associations' do
    let(:user) { User.create(name: 'Test User') }

    it 'inherits associations in history classes' do
      dataset = Dataset.create(name: "test_dataset", history_user_id: user.id)
      model = XGBoost.create(name: "test_model", dataset: dataset, history_user_id: user.id)
      model.snapshot

      dataset.update(name: "new_dataset", history_user_id: user.id)
      
      expect(dataset.ml_model).to eq model # This is still a live model
      expect(model.dataset).to eq(dataset)
      expect(model.histories.first).to respond_to(:dataset)
      expect(model.histories.first.dataset).to be_a(DatasetHistory)

      model_history = model.latest_snapshot
      expect(model_history.dataset.name).to eq "test_dataset"
    end
  end

  describe 'Single Table Inheritance with custom inheritance column' do
    let(:user) { User.create(name: 'Test User') }
    let(:xgboost) do
      XGBoost.create(
        name: 'My XGBoost Model',
        parameters: { max_depth: 3, eta: 0.1 },
        history_user_id: user.id
      )
    end

    it 'creates history records with correct inheritance' do
      model = xgboost
      expect(model.model_name).to eq('XGBoost')
      expect(model.current_history).to be_a(XGBoostHistory)
      expect(model.current_history.model_name).to eq('XGBoostHistory')
    end

    it 'maintains inheritance through updates' do
      model = xgboost
      model.update(name: 'Updated XGBoost Model', history_user_id: user.id)
      
      expect(model.histories.count).to eq(2)
      expect(model.histories.all? { |h| h.is_a?(XGBoostHistory) }).to be true
    end

    it 'reifies with correct class' do
      model = xgboost
      original_name = model.name
      model.update(name: 'Updated XGBoost Model', history_user_id: user.id)
      model.snapshot
      
      reified = model.latest_snapshot
      expect(reified).to be_a(XGBoostHistory)
      expect(reified.name).to eq("Updated XGBoost Model")
    end
  end

  describe 'Class-level mode setting' do
    before(:each) do
      Historiographer::Configuration.mode = :histories
    end

    it "uses class-level snapshot_only mode" do
      class Post < ActiveRecord::Base
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

      class Post < ActiveRecord::Base
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
      expect(col_history.class.history_foreign_key).to eq('column_id')
      expect(col_history).to be_a(EasyML::ColumnHistory)
    end

    it 'establishes correct associations for child classes' do
      encrypted_col = EasyML::Column.create(
        name: 'secret_feature',
        data_type: 'numeric',
        history_user_id: user.id,
        column_type: "EasyML::EncryptedColumn"
      )
      
      # Verify the base record
      expect(encrypted_col).to be_a(EasyML::EncryptedColumn)
      expect(encrypted_col.encrypted?).to be true
      
      # Verify history record
      col_history = encrypted_col.histories.last
      expect(col_history).to be_a(EasyML::EncryptedColumnHistory)
      expect(col_history.class.history_foreign_key).to eq('column_id')
      expect(col_history.encrypted?).to be true
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
end