class AddSystemEmailsToRemoteResources < ActiveRecord::Migration
  def self.up
    add_column    :remote_resources, :support_email,     :string
    add_column    :remote_resources, :system_from_email, :string
  end

  def self.down
    remove_column :remote_resources, :support_email
    remove_column :remote_resources, :system_from_email
  end
end
