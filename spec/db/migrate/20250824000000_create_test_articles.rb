class CreateTestArticles < ActiveRecord::Migration[7.0]
  def change
    create_table :test_articles do |t|
      t.string :title
      t.integer :test_category_id
      t.timestamps
    end
    
    create_table :test_article_histories do |t|
      t.integer :test_article_id, null: false
      t.string :title
      t.integer :test_category_id
      t.timestamps
      
      t.datetime :history_started_at, null: false
      t.datetime :history_ended_at
      t.integer :history_user_id
      t.string :snapshot_id
      
      t.index :test_article_id
      t.index :history_started_at
      t.index :history_ended_at
      t.index :snapshot_id
    end
  end
end