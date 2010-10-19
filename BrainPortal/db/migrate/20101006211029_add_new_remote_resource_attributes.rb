class AddNewRemoteResourceAttributes < ActiveRecord::Migration

  def self.up

    # Portal only
    add_column :remote_resources, :site_url_prefix,        :string

    # All RemoteResources
    add_column :remote_resources, :dp_cache_dir,           :string
    add_column :remote_resources, :dp_ignore_patterns,     :text

    # Bourreau only, Cluster Management System values
    add_column :remote_resources, :cms_class,              :string
    add_column :remote_resources, :cms_default_queue,      :string
    add_column :remote_resources, :cms_extra_qsub_args,    :string
    add_column :remote_resources, :cms_shared_dir,         :string

    # Bourreau only, Workers info
    add_column :remote_resources, :workers_instances,      :integer
    add_column :remote_resources, :workers_chk_time,       :integer
    add_column :remote_resources, :workers_log_to,         :string
    add_column :remote_resources, :workers_verbose,        :integer
     
  end

  def self.down

    # Portal only
    remove_column :remote_resources, :site_url_prefix

    # All RemoteResources
    remove_column :remote_resources, :dp_cache_dir
    remove_column :remote_resources, :dp_ignore_patterns

    # Bourreau only, Cluster Management System values
    remove_column :remote_resources, :cms_class
    remove_column :remote_resources, :cms_default_queue
    remove_column :remote_resources, :cms_extra_qsub_args
    remove_column :remote_resources, :cms_shared_dir

    # Bourreau only, Workers info
    remove_column :remote_resources, :workers_instances
    remove_column :remote_resources, :workers_chk_time
    remove_column :remote_resources, :workers_log_to
    remove_column :remote_resources, :workers_verbose
     
  end

end
