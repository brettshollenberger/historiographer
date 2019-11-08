# Historiographer

Losing data sucks. Every time you update or destroy a record in Rails, you lose the old data.

## Existing auditing gems for Rails suck

The Audited gem has some serious flaws.

🤚Hands up if your `versions` table has gotten too big to query 🤚

🤚Hands up if your `versions` table doesn't have the indexes you need 🤚

🤚Hands up if you've ever iterated over `versions` records in Ruby to recreate a snapshot of what data looked like at a point in time.

Why does this happen?

First, `audited` only tracks a record of what changed, so there's no way to "go back in time" and see what the data looked like back when a problem occurred without replaying every single audit.

Second, it tracks changes as JSON. While some data stores have JSON querying semantics, not all do, making it very hard to ask complex questions of your historical data -- that's the whole reason you're keeping it around.

Third, it doesn't maintain indexes on your data. If you maintain an index on the primary table, wouldn't you also want to look up historical records using the same columns? Historical data is MUCH larger than "latest snapshot" data, so, duh, of course you do.

Finally, Audited creates just one table for all audits. Historical data is big. It's not unusual for an audited gem table to get into the many millions of rows, and need to be constantly partitioned to maintain any kind of efficiency.

## How does Historiographer solve these problems?

Historiographer introduces the concept of _history tables:_ append-only tables that have the same structure and indexes as your primary table.

If you have a `posts` table:

| id | title |
| :----------- | :----------- |
| 1      | My Great Post       |
| 2 | My Second Post |

You'll also have a `post_histories_table`:

| id | post_id | title | history_started_at | history_ended_at | history_user_id |
| :----------- | :----------- | :----------- | :----------- | :----------- | :----------- |
| 1      | 1 | My Great Post | '2019-11-08' | NULL | 1 |
| 2 | 2| My Second Post | '2019-11-08' | NULL | 1 |

If you change the title of the 1st post:

```Post.find(1).update(title: "Title With Better SEO")```

You'll expect your `posts` table to be updated directly:

| id | title |
| :----------- | :----------- |
| 1      | Title With Better SEO |
| 2 | My Second Post |

But also, your `histories` table will be updated:

| id | post_id | title | history_started_at | history_ended_at | history_user_id |
| :----------- | :----------- | :----------- | :----------- | :----------- | :----------- |
| 1      | 1 | My Great Post | '2019-11-08' | '2019-11-09' | 1 |
| 2 | 2| My Second Post | '2019-11-08' | NULL | 1 |
| 1      | 1 | Title With Better SEO | '2019-11-09' | NULL | 1 |

A few things have happened here:

1. The primary table (`posts`) is updated directly
2. The existing history for `post_id=1` is timestamped when its `history_ended_at`, so that we can see when the post had the title "My Great Post"
3. A new history record is appended to the table containing a complete snapshot of the record, and a `NULL` `history_ended_at`. That's because this is the current history. You can always find the current snapshots of records either by querying the primary table (`posts`), or querying the `histories` table using `history_ended_at IS NULL`.

# Getting Started

Whenever you include the `Historiographer` gem in your ActiveRecord model, it allows you to insert, update, or delete data as you normally would. 

## Create A Migration

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

### What to do when generated index names are too long

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

## Models

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

## Creating, Updating, and Destroying Data:

You can just use normal ActiveRecord methods, and all will record histories:

```ruby
Post.create(title: "My Great Title")
Post.find_by(title: "My Great Title").update(title: "A New Title")
Post.update_all(title: "They're all the same!")
Post.last.destroy!
Post.destroy_all
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
