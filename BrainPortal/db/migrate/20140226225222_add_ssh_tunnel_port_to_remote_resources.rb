class AddSshTunnelPortToRemoteResources < ActiveRecord::Migration
  def change
    add_column :remote_resources, :ssh_tunnel_port, :int
  end
end
