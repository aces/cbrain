class ModifyFieldsForTools < ActiveRecord::Migration
  def self.up
    rename_column :tools, :tool_name, :name
    add_column    :tools, :drmaa_class, :string
  end

  def self.down
    rename_column :tools, :name, :tool_name
    remove_column    :tools, :drmaa_class
  end
end
