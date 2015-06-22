class AddOpenStackUserNameToRemoteResource < ActiveRecord::Migration
  def change
    add_column :remote_resources, :open_stack_user_name, :string
  end
end
