class AddBourreauTunnelInfo < ActiveRecord::Migration
  def self.up
    rename_column :remote_resources, :remote_user,           :actres_user
    rename_column :remote_resources, :remote_host,           :actres_host
    rename_column :remote_resources, :remote_port,           :actres_port
    rename_column :remote_resources, :remote_dir,            :actres_dir

    add_column    :remote_resources, :ssh_control_user,      :string
    add_column    :remote_resources, :ssh_control_host,      :string
    add_column    :remote_resources, :ssh_control_port,      :integer

    add_column    :remote_resources, :ssh_control_rails_dir, :string

    add_column    :remote_resources, :tunnel_mysql_port,     :integer
    add_column    :remote_resources, :tunnel_actres_port,    :integer
  end

  def self.down
    rename_column :remote_resources, :actres_host,           :remote_host
    rename_column :remote_resources, :actres_port,           :remote_port
    rename_column :remote_resources, :actres_user,           :remote_user
    rename_column :remote_resources, :actres_dir,            :remote_dir

    remove_column :remote_resources, :ssh_control_user
    remove_column :remote_resources, :ssh_control_host
    remove_column :remote_resources, :ssh_control_port

    remove_column :remote_resources, :ssh_control_rails_dir

    remove_column :remote_resources, :tunnel_mysql_port
    remove_column :remote_resources, :tunnel_actres_port
  end
end
