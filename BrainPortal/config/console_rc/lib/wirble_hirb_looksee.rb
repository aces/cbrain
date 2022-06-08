
#
# Several console initializers from Gems.
# Adds pretty table layouts for serveral CBRAIN models.
#

require 'wirble'
require 'hirb'
require 'looksee'
Wirble.init
Wirble.colorize
Hirb.enable
extend Hirb::Console

# Hirb attribute subsets for each models
{
  'RemoteResource' => %i( id type name
                          user_id group_id online
                          ssh_control_user ssh_control_host ssh_control_rails_dir
                        ),
  'CbrainTask'     => %i( id type status
                          user_id group_id
                          cluster_workdir
                          bourreau_id tool_config_id results_data_provider_id
                          cluster_workdir_size
                        ),
  'Userfile'       => %i( id type name size num_files
                          user_id group_id
                          data_provider_id
                        ),
  'DataProvider'   => %i( id type name
                          user_id group_id online
                          remote_user remote_host remote_dir
                        ),
  'SyncStatus'     => %i( id status
                          userfile_id remote_resource_id accessed_at synced_at
                        ),
  'User'           => %i( id type full_name login email city country last_connected_at account_locked
                        ),
  'Tool'           => %i( id name
                          user_id group_id
                          category cbrain_task_class_name
                        ),
  'Group'          => %i( id type name site_id creator_id invisible public
                        ),
  'Site'           => %i( id name
                        ),
  'ToolConfig'     => %i( id version_name
                          group_id
                          tool_id bourreau_id
                          ncpus container_engine
                        ),
  'Tag'            => %i( id name
                          user_id group_id
                        ),
  'AccessProfile'  => %i( id name
                        ),
  'ResourceUsage'  => %i( id type value remote_resource_name userfile_name cbrain_task_type user_login
                        ),
  'MetaDataStore'  => %i( id ar_id ar_table_name meta_key meta_value
                        ),
  'Signup'         => %i( id first last email position institution confirmed approved_by user_id
                        ),
  'DiskQuota'      => %i( id user_id data_provider_id max_bytes max_files
                        ),
  'DataUsage'      => %i( id user_id group_id yearmonth
                          views_count       views_numfiles
                          downloads_count   downloads_numfiles
                          copies_count      copies_numfiles
                          task_setups_count task_setups_numfiles
                        ),

}.each do |klassname,fields|
  fields = fields.dup
  klass  = klassname.constantize rescue nil
  next unless klass # e.g. in irb instead of Rails console
  fields << :created_at if klass.attribute_names.include?('created_at') && ! [ 'DataUsage' ].include?(klassname)
  fields << :updated_at if klass.attribute_names.include?('updated_at') && ! [ 'DataUsage' ].include?(klassname)
  Hirb::Formatter.dynamic_config[klassname] = {
    :class     => Hirb::Helpers::AutoTable,
    :ancestor  => true,
    :options   => { :fields => fields, :unicode => true },
  }
end

# Table view with all attributes
def tv(*args)
  no_log do
    to_show = args.flatten
    to_show.each_with_index do |obj,idx|
      if obj.respond_to?(:attributes)
        table obj.attributes, :unicode => true, :headers => false
      else
        table obj, :unicode => true, :headers => false
      end
      if idx+1 >= $_PV_MAX_SHOW && to_show.size > $_PV_MAX_SHOW
        puts "Not showing #{to_show.size - $_PV_MAX_SHOW} other entries..."
        break
      end
    end
  end
  true
end

# Table view of things with pretty borders and no headers
def htable(thingie, options={})
  table thingie, options.merge(:unicode => true, :headers => false)
end

(CbrainConsoleFeatures ||= []) << <<FEATURES
========================================================
Feature: Hirb pretty model tables, and table helpers
========================================================
  Models have pretty unicode tables: User.limit(4)
  Full attributes in tables with: 'tv obj'
  Console commands: 'table', 'htable' and 'view'
  Toggle with: Hirb.enable ; Hirb.disable
  (See the doc for the gem Hirb for more info)
FEATURES

