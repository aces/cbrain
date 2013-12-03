class AddOpenStackTenantToRemoteResource < ActiveRecord::Migration
  def change
    add_column :remote_resources, :open_stack_tenant, :string
  end
end
