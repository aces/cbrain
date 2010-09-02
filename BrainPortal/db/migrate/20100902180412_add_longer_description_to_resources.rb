class AddLongerDescriptionToResources < ActiveRecord::Migration
  def self.up
    change_column :data_providers,   :description, :text
    change_column :remote_resources, :description, :text
  end

  def self.down
    change_column :data_providers,   :description, :string
    change_column :remote_resources, :description, :string
  end
end
