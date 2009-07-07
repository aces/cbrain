class AddTagsToCustomFilter < ActiveRecord::Migration
  def self.up
    add_column :custom_filters, :tags, :text
  end

  def self.down
    remove_column :custom_filters, :tags
  end
end
