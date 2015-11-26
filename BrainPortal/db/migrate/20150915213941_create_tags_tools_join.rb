class CreateTagsToolsJoin < ActiveRecord::Migration
  def self.up
    create_table :tags_tools, :id => false do |t|
      t.integer   :tag_id
      t.integer   :tool_id
    end
  end

  def self.down
    drop_table :tags_tools
  end
end

