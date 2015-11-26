class DropTagsToolTable < ActiveRecord::Migration
  def up
    drop_table :tags_tools
  end

  def down
  end
end
