require "spec_helper"

class Post < ActiveRecord::Base
  include Historiographer
end

class PostHistory < ActiveRecord::Base
end

class SafePost < ActiveRecord::Base
  include Historiographer::Safe
end

class SafePostHistory < ActiveRecord::Base
end

class Author < ActiveRecord::Base
  include Historiographer
end

class AuthorHistory < ActiveRecord::Base
end

class User < ActiveRecord::Base
end

describe Historiographer do
  before(:all) do
    @now = Timecop.freeze
  end

  after(:all) do
    Timecop.return
  end

  let(:username) { "Test User" }

  let(:user) do
    User.create(name: username)
  end

  let(:create_post) do
    Post.create(
      title: "Post 1",
      body: "Great post",
      author_id: 1,
      history_user_id: user.id
    )
  end

  let(:create_author) do
    Author.create(
      full_name: "Breezy",
      history_user_id: user.id
    )
  end

  describe "History counting" do
    it "creates history on creation of primary model record" do
      expect {
        create_post
      }.to change {
        PostHistory.count
      }.by 1
    end

    it "appends new history on update" do
      post = create_post

      expect {
        post.update(title: "Better Title")
      }.to change {
        PostHistory.count
      }.by 1
    end

    it "does not append new history if nothing has changed" do
      post = create_post

      expect { 
        post.update(title: post.title)
      }.to_not change {
        PostHistory.count
      }
    end
  end

  describe "History recording" do
    it "records all fields from the parent" do
      post         = create_post
      post_history = post.histories.first

      expect(post_history.title).to eq     post.title
      expect(post_history.body).to eq      post.body
      expect(post_history.author_id).to eq post.author_id
      expect(post_history.post_id).to eq   post.id
      expect(post_history.history_started_at).to eq @now.in_time_zone(Historiographer::UTC)
      expect(post_history.history_ended_at).to be_nil
      expect(post_history.history_user_id).to eq user.id

      post.update(title: "Better title")
      post_histories = post.histories.reload.order("id asc")
      first_history  = post_histories.first
      second_history = post_histories.second

      expect(first_history.history_ended_at).to eq @now.in_time_zone(Historiographer::UTC)
      expect(second_history.history_ended_at).to be_nil
    end

    it "cannot create without history_user_id" do
      post = Post.create(
        title: "Post 1",
        body: "Great post",
        author_id: 1,
      ) 
      expect(post.errors.to_h).to eq({ :history_user_id => "must be an integer" })

      expect {
        post.send(:record_history)
      }.to raise_error(
        Historiographer::HistoryUserIdMissingError
      )
    end

    context "When Safe mode" do
      it "creates history without history_user_id" do
        expect(Rollbar).to receive(:error).with("history_user_id must be passed in order to save record with histories! If you are in a context with no history_user_id, explicitly call #save_without_history")

        post = SafePost.create(
          title: "Post 1",
          body: "Great post",
          author_id: 1,
        ) 
        expect(post.errors.to_h.keys).to be_empty
        expect(post).to be_persisted
        expect(post.histories.count).to eq 1
        expect(post.histories.first.history_user_id).to be_nil
      end

      it "creates history with history_user_id" do
        expect(Rollbar).to_not receive(:error)

        post = SafePost.create(
          title: "Post 1",
          body: "Great post",
          author_id: 1,
          history_user_id: user.id
        ) 
        expect(post.errors.to_h.keys).to be_empty
        expect(post).to be_persisted
        expect(post.histories.count).to eq 1
        expect(post.histories.first.history_user_id).to eq user.id
      end

       it "skips history creation if desired" do
        post = SafePost.new(
          title: "Post 1",
          body: "Great post",
          author_id: 1
        ) 

        post.save_without_history
        expect(post).to be_persisted
        expect(post.histories.count).to eq 0
       end
    end

    it "can override without history_user_id" do
      expect { 
        post = Post.new(
          title: "Post 1",
          body: "Great post",
          author_id: 1,
        ) 

        post.save_without_history
      }.to_not raise_error
    end

    it "can override without history_user_id" do
      expect { 
        post = Post.new(
          title: "Post 1",
          body: "Great post",
          author_id: 1,
        ) 

        post.save_without_history!
      }.to_not raise_error
    end

    it "does not record histories when main model fails to save" do
      class Post
        after_save :raise_error, prepend: true

        def raise_error
          raise "Oh no, db issue!"
        end
      end

      expect { create_post }.to raise_error
      expect(PostHistory.count).to be 0

      Post.skip_callback(:save, :after, :raise_error)
    end
  end

  describe "Scopes" do
    it "finds current histories" do
      post1 = create_post
      post1.update(title: "Better title")

      post2 = create_post
      post2.update(title: "Better title")

      expect(PostHistory.current.pluck(:title)).to all eq "Better title"
      expect(post1.current_history.title).to eq "Better title"
    end
  end

  describe "Associations" do
    it "names associated records" do
      post1 = create_post
      expect(post1.histories.first).to be_a(PostHistory)

      expect(post1.histories.first.post).to be(post1)

      author1 = create_author
      expect(author1.histories.first).to be_a(AuthorHistory)

      expect(author1.histories.first.author).to be(author1)
    end
  end

  describe "Histories" do
    it "does not allow direct updates of histories" do
      post1 = create_post
      hist1 = post1.histories.first

      expect(hist1.update(title: "A different title")).to be false
      expect(hist1.reload.title).to eq post1.title

      expect(hist1.update!(title: "A different title")).to be false
      expect(hist1.reload.title).to eq post1.title

      hist1.title = "A different title"
      expect(hist1.save).to be false
      expect(hist1.reload.title).to eq post1.title

      hist1.title = "A different title"
      expect(hist1.save!).to be false
      expect(hist1.reload.title).to eq post1.title
    end

    it "does not allow destroys of histories" do
      post1                  = create_post
      hist1                  = post1.histories.first
      original_history_count = post1.histories.count

      expect(hist1.destroy).to be false
      expect(hist1.destroy!).to be false

      expect(post1.histories.count).to be original_history_count
    end
  end
  
  describe "Deletion" do
    it "records deleted_at on primary and history if you use acts_as_paranoid" do
      class Post
        acts_as_paranoid
      end

      post = create_post

      expect {
        post.destroy
      }.to change {
        PostHistory.count
      }.by 1

      expect(Post.unscoped.where.not(deleted_at: nil).count).to eq 1
      expect(Post.unscoped.where(deleted_at: nil).count).to eq 0
      expect(PostHistory.where.not(deleted_at: nil).count).to eq 1
      expect(PostHistory.where(deleted_at: nil).count).to eq 1
    end
  end

  describe "Scopes" do
    it "finds current" do
      post = create_post
      post.update(title: "New Title")
      post.update(title: "New Title 2")

      expect(PostHistory.current.count).to be 1
    end

    it "finds current even when the db is updated in an invalid way" do
      sql = <<-SQL
        INSERT INTO post_histories (
          title,
          body,
          post_id,
          author_id,
          history_started_at,
          history_ended_at
        ) VALUES (
          'Post 1',
          'Text',
          1,
          1,
          now() - INTERVAL '1 day',
          NULL
        ), (
          'Post 1',
          'Different text',
          1,
          1,
          now() - INTERVAL '12 hours',
          NULL
        ), (
          'Post 1',
          'Even more different text',
          1,
          1,
          now() - INTERVAL '12 hours',
          NULL
        )
      SQL

      PostHistory.connection.execute(sql)

      expect(PostHistory.current.count).to be 1
      expect(PostHistory.current.first.body).to eq "Even more different text"
    end
  end

  describe "User associations" do
    it "links to user" do
      post = create_post
      author = create_author

      expect(post.current_history.user.name).to eq username
      expect(author.current_history.user.name).to eq username
    end
  end
end
