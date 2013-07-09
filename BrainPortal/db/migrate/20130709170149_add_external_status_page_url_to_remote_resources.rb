class AddExternalStatusPageUrlToRemoteResources < ActiveRecord::Migration
  def change
    add_column :remote_resources, :external_status_page_url, :string
  end
end
