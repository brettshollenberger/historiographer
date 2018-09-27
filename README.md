# historiographer

Losing data sucks. Querying your data at any point in history, using the same indices you normally would, rules.

So how can you do this in Rails?

Active Record hates append-only. Querying a single table for the latest data is the the default, because caches are useful.

So query like you normally would. Create, update, and destroy like you normally would. All of ActiveRecord is the same, *plus* you get tables filled with all of your historical data, for *free.*

# basic use

## migrations

You need a separate table to store histories for each model.

So if you have a Posts model:

```ruby
class CreatePosts < ActiveRecord::Migration
  def change
    create_table :posts do |t|
      t.string :title, null: false
      t.boolean :enabled
    end
    add_index :posts, :enabled
  end
end
```

You should create a model named *posts_histories*:

```ruby
require "historiographer/postgres_migration"
class CreatePostHistories < ActiveRecord::Migration
  def change
    create_table :post_histories do |t|
      t.histories
    end
  end
end
```

The `t.histories` method will automatically create a table with the following columns:

* `id` (because every model has a primary key)
* `post\_id` (because this is the foreign key)
* `title` (because it was on the original model)
* `enabled` (because it was on the original model)
* `history\_started\_at` (to denote when this history became the canonical version)
* `history\_ended\_at` (to denote when this history was no longer the canonical version, if it has stopped being the canonical version)
* `history\_user\_id` (to denote the user that made this change, if one is known)

Additionally it will add indices on:

* The same columns that had indices on the original model (e.g. `enabled`)
* `history\_started\_at`, `history\_ended\_at`, and `history\_user\_id`

## models

The primary model should include `Historiographer`:

```ruby
class Post
  include Historiographer
end
```

You should also make a `PostHistory` class if you're going to query `PostHistory` from Rails:

```ruby
class PostHistory
end
```

The `Posts` class will acquire a `histories` method, and the `PostHistory` model will gain a `post` method:

```ruby
p = Post.first
p.histories.first.class

# => "PostHistory"

p.histories.first.post == p
# => true
```

The `histories` classes have a `current` method, which only finds current history records. These records will also be the same as the data in the primary table.

```ruby
p = Post.first
p.current_history

PostHistory.current
```

== Copyright

Copyright (c) 2016 brettshollenberger. See LICENSE.txt for
further details.
