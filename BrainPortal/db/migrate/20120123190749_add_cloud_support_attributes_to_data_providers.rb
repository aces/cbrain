class AddCloudSupportAttributesToDataProviders < ActiveRecord::Migration
  def self.up
    add_column    :data_providers, :cloud_storage_client_identifier, :string
    add_column    :data_providers, :cloud_storage_client_token,      :string
  end

  def self.down
    remove_column :data_providers, :cloud_storage_client_identifier
    remove_column :data_providers, :cloud_storage_client_token
  end
end
