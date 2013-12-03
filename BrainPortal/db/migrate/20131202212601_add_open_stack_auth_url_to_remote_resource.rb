class AddOpenStackAuthUrlToRemoteResource < ActiveRecord::Migration
  def change
    add_column :remote_resources, :open_stack_auth_url, :string
  end
end
