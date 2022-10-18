# frozen_string_literal: true

require 'spec_helper'

class Post < ActiveRecord::Base
  include Historiographer
  acts_as_paranoid
end

class PostHistory < ActiveRecord::Base
end

class SafePost < ActiveRecord::Base
  include Historiographer::Safe
  acts_as_paranoid
end

class SafePostHistory < ActiveRecord::Base
end

class SilentPost < ActiveRecord::Base
  include Historiographer::Silent
  acts_as_paranoid
end

class SilentPostHistory < ActiveRecord::Base
end

class Author < ActiveRecord::Base
  include Historiographer
end

class AuthorHistory < ActiveRecord::Base
end

class User < ActiveRecord::Base
end

class ThingWithCompoundIndex < ActiveRecord::Base
  include Historiographer
end

class ThingWithCompoundIndexHistory < ActiveRecord::Base
end

class ThingWithoutHistory < ActiveRecord::Base
end

describe Historiographer do
  before(:all) do
    @now = Timecop.freeze
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
      expect(post_history.history_started_at.to_s).to eq @now.in_time_zone(Historiographer::UTC).to_s
      expect(post_history.history_ended_at).to be_nil
      expect(post_history.history_user_id).to eq user.id

      post.update(title: 'Better title')
      post_histories = post.histories.reload.order('id asc')
      first_history  = post_histories.first
      second_history = post_histories.second

      expect(first_history.history_ended_at.to_s).to eq @now.in_time_zone(Historiographer::UTC).to_s
      expect(second_history.history_ended_at).to be_nil
    end

    it 'cannot create without history_user_id' do
      post = Post.create(
        title: 'Post 1',
        body: 'Great post',
        author_id: 1
      )
      expect(post.errors.to_h).to eq(history_user_id: 'must be an integer')

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

          expect(ThingWithoutHistory.all.map(&:name)).to all(eq 'Thing 3')
          expect(ThingWithoutHistory.all).to_not respond_to :has_histories?
          expect(ThingWithoutHistory.all).to_not respond_to :update_all_without_history
          expect(ThingWithoutHistory.all).to_not respond_to :delete_all_without_history
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
          expect(PostHistory.count).to eq 6
          expect(PostHistory.current.count).to eq 3
          expect(PostHistory.current.map(&:deleted_at)).to all(eq Time.now)
          expect(PostHistory.current.map(&:history_user_id)).to all(eq 1)
          expect(PostHistory.where(deleted_at: nil).where.not(history_ended_at: nil).count).to eq 3
          expect(PostHistory.where(history_ended_at: nil).count).to eq 3
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
          expect(PostHistory.count).to eq 6
          expect(PostHistory.current.count).to eq 3
          expect(PostHistory.current.map(&:deleted_at)).to all(eq Time.now)
          expect(PostHistory.current.map(&:history_user_id)).to all(eq 1)
          expect(PostHistory.where(deleted_at: nil).where.not(history_ended_at: nil).count).to eq 3
          expect(PostHistory.where(history_ended_at: nil).count).to eq 3
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
        expect(post.errors.to_h.keys).to be_empty
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
        expect(post.errors.to_h.keys).to be_empty
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
        expect(post.errors.to_h.keys).to be_empty
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
        expect(post.errors.to_h.keys).to be_empty
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

      expect(post1.histories.first.post).to be(post1)

      author1 = create_author
      expect(author1.histories.first).to be_a(AuthorHistory)

      expect(author1.histories.first.author).to be(author1)
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
        PostHistory.count
      }.by 1

      expect(Post.unscoped.where.not(deleted_at: nil).count).to eq 1
      expect(Post.unscoped.where(deleted_at: nil).count).to eq 0
      expect(PostHistory.where.not(deleted_at: nil).count).to eq 1
      expect(PostHistory.last.history_user_id).to eq 2
    end

    it 'works with Historiographer::Safe' do
      post = SafePost.create(title: 'HELLO', body: 'YO', author_id: 1)

      expect do
        post.destroy
      end.to_not raise_error

      expect(SafePost.count).to eq 0
      expect(post.deleted_at).to_not be_nil
      expect(SafePostHistory.count).to eq 2
      expect(SafePostHistory.current.last.deleted_at).to eq post.deleted_at

      post2 = SafePost.create(title: 'HELLO', body: 'YO', author_id: 1)

      expect do
        post2.destroy!
      end.to_not raise_error

      expect(SafePost.count).to eq 0
      expect(post2.deleted_at).to_not be_nil
      expect(SafePostHistory.count).to eq 4
      expect(SafePostHistory.current.where(safe_post_id: post2.id).last.deleted_at).to eq post2.deleted_at
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
end
