class AddJumpHostConfigToBourreaux < ActiveRecord::Migration[5.0]
  def change
    remove_column :remote_resources, :proxied_host,  :string
    add_column    :remote_resources, :jumphost_host, :string,  :after => :ssh_control_rails_dir
    add_column    :remote_resources, :jumphost_user, :string,  :after => :jumphost_host
    add_column    :remote_resources, :jumphost_port, :integer, :after => :jumphost_user
  end
end
