# Historiographer

Losing data sucks. Every time you update or destroy a record in Rails, you lose the old data.

Historiographer fixes this problem in a better way than existing auditing gems.

## Existing auditing gems for Rails suck

The Audited gem has some serious flaws.

1. The `versions` table quickly grows too large to query

2. It doesn't provide the indexes you need from your primary tables

3. It doesn't provide out-of-the-box snapshots

## How does Historiographer solve these problems?

Historiographer introduces the concept of _history tables:_ append-only tables that have the same structure and indexes as your primary table.

If you have a `posts` table:

| id  | title          |
| :-- | :------------- |
| 1   | My Great Post  |
| 2   | My Second Post |

You'll also have a `post_histories_table`:

| id  | post_id | title          | history_started_at | history_ended_at | history_user_id |
| :-- | :------ | :------------- | :----------------- | :--------------- | :-------------- |
| 1   | 1       | My Great Post  | '2019-11-08'       | NULL             | 1               |
| 2   | 2       | My Second Post | '2019-11-08'       | NULL             | 1               |

If you change the title of the 1st post:

`Post.find(1).update(title: "Title With Better SEO", history_user_id: current_user.id)`

You'll expect your `posts` table to be updated directly:

| id  | title                 |
| :-- | :-------------------- |
| 1   | Title With Better SEO |
| 2   | My Second Post        |

But also, your `histories` table will be updated:

| id  | post_id | title                 | history_started_at | history_ended_at | history_user_id |
| :-- | :------ | :-------------------- | :----------------- | :--------------- | :-------------- |
| 1   | 1       | My Great Post         | '2019-11-08'       | '2019-11-09'     | 1               |
| 2   | 2       | My Second Post        | '2019-11-08'       | NULL             | 1               |
| 1   | 1       | Title With Better SEO | '2019-11-09'       | NULL             | 1               |

A few things have happened here:

1. The primary table (`posts`) is updated directly
2. The existing history for `post_id=1` is timestamped when its `history_ended_at`, so that we can see when the post had the title "My Great Post"
3. A new history record is appended to the table containing a complete snapshot of the record, and a `NULL` `history_ended_at`. That's because this is the current history.
4. A record of _who_ made the change is saved (`history_user_id`). You can join to your users table to see more data.

## Snapshots

Snapshots are particularly useful for two key use cases:

### 1. Time Travel & Auditing

When you need to see exactly what your data looked like at a specific point in time - not just individual records, but entire object graphs with all their associations. This is invaluable for:

- Debugging production issues ("What did the entire order look like when this happened?")
- Compliance requirements ("Show me the exact state of this patient's record on January 1st")
- Auditing complex workflows ("What was the state of this loan application when it was approved?")

### 2. Machine Learning & Analytics

When you need immutable snapshots of data for:

- Training data versioning
- Feature engineering
- Model validation
- A/B test analysis
- Ensuring reproducibility of results

### Taking Snapshots

You can take a snapshot of a record and all its associated records:

```ruby
post = Post.find(1)
post.snapshot
```

This will:

1. Create a history record for the post
2. Recursively create history records for all associated records that also include Historiographer (comments, author, etc.)
3. Link these history records together with a shared `snapshot_id`
4. Skip any view-backed models (models without a primary key)

**Note:** The snapshot cascades to ALL associations where the associated model includes Historiographer. There is currently no built-in way to limit which associations get snapshotted. If you need finer control, you can either not include Historiographer on models you don't want snapshotted, or override the `snapshot` method.

You can retrieve the latest snapshot using:

```ruby
post = Post.find(1)
snapshot = post.latest_snapshot

# Access associated records from the snapshot
snapshot.comments # Returns CommentHistory records
snapshot.author   # Returns AuthorHistory record
```

Snapshots are immutable - you cannot modify history records that are part of a snapshot. This guarantees that your historical data remains unchanged, which is crucial for both auditing and machine learning applications.

### Snapshot-Only Mode

If you want to only track snapshots and not record every individual change, you can configure Historiographer to operate in snapshot-only mode:

```ruby
Historiographer::Configuration.mode = :snapshot_only
```

In this mode:

- Regular updates/changes will not create history records
- Only explicit calls to `snapshot` will create history records
- Each snapshot still captures the complete state of the record and its associations

This can be useful when:

- You only care about specific points in time rather than every change
- You want to reduce the number of history records created
- You need to capture the state of complex object graphs at specific moments
- You're versioning training data for machine learning models
- You need to maintain immutable audit trails at specific checkpoints

## Safe and Silent Modes

Historiographer provides two additional modes for migrating existing models:

### Historiographer::Safe

Use `Historiographer::Safe` when migrating an existing model to Historiographer. Instead of raising an error when `history_user_id` is missing, it logs to Rollbar, allowing you to find all locations that need to be updated:

```ruby
class Post < ActiveRecord::Base
  include Historiographer::Safe
end

# This will create a history record and log to Rollbar (instead of raising an error)
Post.create(title: "My Post")
```

### Historiographer::Silent

Use `Historiographer::Silent` when you want to allow missing `history_user_id` without any errors or logging:

```ruby
class Post < ActiveRecord::Base
  include Historiographer::Silent
end

# This will create a history record silently without history_user_id
Post.create(title: "My Post")
```

**Note:** Both Safe and Silent modes are intended for migration purposes, not as long-term solutions.

## Namespaced Models

When using namespaced models, Rails handles foreign key naming differently than with non-namespaced models. For example, if you have a model namespaced like this:

```ruby
module EasyML
  class Dataset
     self.table_name = "easy_ml_datasets"
  end
end
```

Rails will expect foreign keys to be formatted using just the model name (without the namespace) like this:

```ruby
:dataset_id
```

Therefore, when creating history migrations for namespaced models, you need to specify the foreign key name explicitly:

```ruby
class CreateEasyMLDatasetHistories < ActiveRecord::Migration
  def change
    create_table :easy_ml_dataset_histories do |t|
      t.histories(foreign_key: :dataset_id) # instead of using the table name — easy_ml_dataset_id
    end
  end
end
```

This ensures that the foreign key relationships are properly established between your namespaced models and their history tables.

## Getting Started

Whenever you include the `Historiographer` gem in your ActiveRecord model, it allows you to insert, update, or delete data as you normally would.

```ruby
class Post < ActiveRecord::Base
  include Historiographer
end

class PostHistory < ActiveRecord::Base
  self.table_name = "post_histories"
  include Historiographer::History
end
```

### History Modes

Historiographer supports two modes of operation:

1. **:histories mode** (default) - Records history for every change to a record
2. **:snapshot_only mode** - Only records history when explicitly taking snapshots

You can configure the mode globally:

```ruby
# In an initializer
Historiographer::Configuration.mode = :histories  # Default mode
# or
Historiographer::Configuration.mode = :snapshot_only
```

Or per model using `historiographer_mode`:

```ruby
class Post < ActiveRecord::Base
  include Historiographer
  historiographer_mode :snapshot_only  # Only record history when .snapshot is called
end

class Comment < ActiveRecord::Base
  include Historiographer
  historiographer_mode :histories  # Record history for every change (default)
end
```

The class-level mode setting takes precedence over the global configuration. This allows you to:

- Have different history tracking strategies for different models
- Set most models to use snapshots while keeping detailed history for critical models
- Optimize storage by only tracking detailed history where needed

For example:

```ruby
# Global setting for most models
Historiographer::Configuration.mode = :snapshot_only

class Order < ActiveRecord::Base
  include Historiographer
  # Uses global :snapshot_only mode
end

class Payment < ActiveRecord::Base
  include Historiographer
  historiographer_mode :histories  # Override to record histories of every change
end
```

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

## Models

The primary model should include `Historiographer`:

```ruby
class Post < ActiveRecord::Base
  include Historiographer
end

class PostHistory < ActiveRecord::Base
  self.table_name = "post_histories"
  include Historiographer::History
end
```

You should also make a `PostHistory` class if you're going to query `PostHistory` from Rails:

```ruby
class PostHistory < ActiveRecord::Base
  self.table_name = "post_histories"
  include Historiographer::History
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
Post.create(title: "My Great Title", history_user_id: current_user.id)
Post.find_by(title: "My Great Title").update(title: "A New Title", history_user_id: current_user.id)
Post.update_all(title: "They're all the same!", history_user_id: current_user.id)
Post.last.destroy!(history_user_id: current_user.id)
Post.destroy_all(history_user_id: current_user.id)
```

### Skipping History

If you need to save a record without creating a history entry:

```ruby
post = Post.new(title: "My Post")
post.save_without_history    # No history_user_id required
post.save_without_history!   # Bang version

# For bulk operations:
Post.all.update_all_without_history(title: "New Title")
Post.all.delete_all_without_history
Post.all.destroy_all_without_history
```

The `histories` classes have a `current` method, which only finds current history records. These records will also be the same as the data in the primary table.

```ruby
p = Post.first
p.current_history

PostHistory.current
```

### What to do when generated index names are too long

Sometimes the generated index names are too long. Just like with standard Rails migrations, you can override the name of the index to fix this problem. To do so, use the `index_names` argument to override individual index names:

```ruby
require "historiographer/postgres_migration"
class CreatePostHistories < ActiveRecord::Migration
  def change
    create_table :post_histories do |t|
      t.histories index_names: {
        title: "my_index_name",
        [:compound, :index] => "my_compound_index_name"
      }
    end
  end
end
```

== Mysql Install

For contributors on OSX, you may have difficulty installing mysql:

```
gem install mysql2 -v '0.4.10' --source 'https://rubygems.org/' -- --with-ldflags=-L/usr/local/opt/openssl/lib --with-cppflags=-I/usr/local/opt/openssl/include
```

== Testing

```bash
# Initial setup
bin/setup

# Run tests
bin/test        # Regular test suite (fast)
bin/test-rails  # Rails integration tests (slower)
bin/test-all    # Both test suites

# Interactive console
bin/console
```

== Copyright

Copyright (c) 2016-2025 brettshollenberger. See LICENSE.txt for
further details.
