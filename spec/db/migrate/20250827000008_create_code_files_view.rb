class CreateCodeFilesView < ActiveRecord::Migration[7.0]
  def up
    execute <<-SQL
      CREATE OR REPLACE VIEW code_files AS
      WITH merged_files AS (
        -- Get all website files
        SELECT 
          wf.website_id,
          wf.path,
          wf.content,
          wf.content_tsv,
          wf.shasum,
          wf.file_specification_id,
          wf.created_at,
          wf.updated_at,
          'WebsiteFile' AS source_type,
          wf.id AS source_id
        FROM website_files wf
        
        UNION ALL
        
        -- Get template files that don't have a matching website file
        SELECT 
          w.id AS website_id,
          tf.path,
          tf.content,
          tf.content_tsv,
          tf.shasum,
          tf.file_specification_id,
          tf.created_at,
          tf.updated_at,
          'TemplateFile' AS source_type,
          tf.id AS source_id
        FROM template_files tf
        INNER JOIN websites w ON w.template_id = tf.template_id
        WHERE NOT EXISTS (
          SELECT 1 
          FROM website_files wf2 
          WHERE wf2.website_id = w.id 
            AND wf2.path = tf.path
        )
      )
      SELECT 
        website_id,
        path,
        content,
        content_tsv,
        shasum,
        file_specification_id,
        source_type,
        source_id,
        created_at,
        updated_at
      FROM merged_files
      ORDER BY website_id, path;
    SQL
  end

  def down
    execute "DROP VIEW IF EXISTS code_files;"
  end
end