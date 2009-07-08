class CreateInitialBourreaux < ActiveRecord::Migration
  def self.up
    cluster_list = CBRAIN::Cluster_list
    cluster_urls = CBRAIN::Clusters_resource_sites

    admin_id          = User.find_by_login("admin").id
    everyone_group_id = Group.find_by_name("everyone").id

    cluster_list.each do |bourreau_name|
      url      = cluster_urls[bourreau_name]
      raise "Error: can't find URL for bourreau name '#{bourreau_name}' ?!?" unless url
      unless match = url.match(/^http:\/\/([^\/:]+)(:(\d+))?(\/\S*)/)
        raise "Error: can't parse URL '#{url}'."
      end
      host = match[1]
      port = match[3] || 80 # index 2 of match is ignored
      dir  = match[4]
      
      bourreau = Bourreau.create(
        :name        => bourreau_name,

        :remote_host => host,
        :remote_port => port,
        :remote_dir  => dir,

        :description => "Created automatically by DB migration",

        :online      => true,
        :user_id     => admin_id,
        :group_id    => everyone_group_id
      )

    end
  end

  def self.down
    cluster_list = CBRAIN::Cluster_list
    cluster_list.each do |bourreau_name|
      bourreau = RemoteResource.find_by_name(bourreau_name)
      next unless bourreau
      bourreau.destroy
    end
  end
end
