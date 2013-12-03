class AddOpenStackPasswordToRemoteResource < ActiveRecord::Migration
  def change
    add_column :remote_resources, :open_stack_password, :string
  end
end
