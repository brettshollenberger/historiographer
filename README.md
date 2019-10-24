# historiographer

Losing data sucks. Every time you update a record in Rails, by default, you lose the old data.

Supported for PostgreSQL and MySQL. If you need other adapters, help us make one!

## Existing auditing gems for Rails suck

The Audited gem has some serious flaws.

First, it only tracks a record of what changed, so there's no way to "go back in time" and see what the data looked like back when a problem occurred without replaying every single audit.

Second, it tracks changes as JSON. While some data stores have JSON querying semantics, not all do, making it very hard to ask complex questions of your historical data -- that's the whole reason you're keeping it around.

Third, it doesn't maintain efficient indexes on your data. If you maintain an index on the primary records, wouldn't you also want to look up historical records using the same columns? Historical data is MUCH larger than "latest snapshot" data, so, duh, of course you do.

Finally, Audited creates one table for every audit. As mentioned before, historical data is big. It's not unusual for an audited gem table to get into the many millions of rows, and need to be constnatly partitioned to maintain any kind of efficiency.

## How does Historiographer solve the problem?

You have existing code written in Rails, so our existing queries need to Just Work.

Moreover, there are benefits to the Active Record model of updating records in place: the latest snapshot is cached, and accessing it is efficient.

So how can we get the benefits of caching but NOT losing data, and continue to create, update, and destroy like we normally would in Rails?

Historiographer introduces the concept of _history tables:_ tables that have the exact same structure as tables storing the latest snapshots of data. So if you have a `posts` table, you'll also have a `post_histories` table with all the same columns and indexes.

Whenever you include the `Historiographer` gem in your ActiveRecord model, it allows you to insert, update, or delete data as you normally would. If the changes are successful, it also inserts a new history snapshot in the histories table--an exact snapshot of the data at that point in time.

These tables feature two useful indexes: `history_started_at` and `history_ended_at`, which allow you to see what the data looked like and when. You can easily create views which show the total lifecycle of a piece of data, or restore earlier versions directly from these snapshots.

And of course, it contains a migrations tool to help you write the same migrations you normally would without having to worry about also synchronizing histories tables.

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

You should create a model named _posts_histories_:

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

- `id` (because every model has a primary key)
- `post_id` (because this is the foreign key)
- `title` (because it was on the original model)
- `enabled` (because it was on the original model)
- `history_started_at` (to denote when this history became the canonical version)
- `history_ended_at` (to denote when this history was no longer the canonical version, if it has stopped being the canonical version)
- `history_user_id` (to denote the user that made this change, if one is known)

Additionally it will add indices on:

- The same columns that had indices on the original model (e.g. `enabled`)
- `history_started_at`, `history_ended_at`, and `history_user_id`

### what to do when generated index names are too long

Sometimes the generated index names are too long. Just like with standard Rails migrations, you can override the name of the index to fix this problem. To do so, use the `index_names` argument to override individual index names:

```ruby
require "historiographer/postgres_migration"
class CreatePostHistories < ActiveRecord::Migration
  def change
    create_table :post_histories do |t|
      t.histories, index_names: {
        title: "my_index_name",
        [:compound, :index] => "my_compound_index_name"
      }
    end
  end
end
```

## models

The primary model should include `Historiographer`:

```ruby
class Post < ActiveRecord::Base
  include Historiographer
end
```

You should also make a `PostHistory` class if you're going to query `PostHistory` from Rails:

```ruby
class PostHistory < ActiveRecord::Base
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

Copyright (c) 2016-2018 brettshollenberger. See LICENSE.txt for
further details.
