class RemoveOldRemoteRessourcesAttributes < ActiveRecord::Migration[5.0]
  def change
    remove_column :remote_resources, :nh_email_delivery_options, :text,    :after => :nh_system_from_email
    remove_column :remote_resources, :tunnel_mysql_port,         :integer
    remove_column :remote_resources, :tunnel_actres_port,        :integer
  end
end
