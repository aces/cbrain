class AddTimeZoneToUsersAndResources < ActiveRecord::Migration
  def self.up
    add_column    :users,            :time_zone, :string
    add_column    :remote_resources, :time_zone, :string
    add_column    :data_providers,   :time_zone, :string
  end

  def self.down
    remove_column :users,            :time_zone
    remove_column :remote_resources, :time_zone
    remove_column :data_providers,   :time_zone
  end
end
