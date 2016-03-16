class AddTagInfoToTools < ActiveRecord::Migration
  def change
    add_column :tools, :application_package_name, :string
    add_column :tools, :application_type, :string
    add_column :tools, :application_tags, :string
  end
end
