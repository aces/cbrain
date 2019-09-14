class AddResourceUsageTable < ActiveRecord::Migration[5.0]

  def change
    create_table :resource_usage do |t|

      # Type indicate what type of resource and action
      t.string  :type      # for single table inheritance

      # The value being tracked
      t.decimal :value, precision: 24

      # Owner and/or group that used the value
      t.integer :user_id,                  :optional => true
      t.string  :user_type,                :optional => true
      t.string  :user_login,               :optional => true
      t.integer :group_id,                 :optional => true
      t.string  :group_type,               :optional => true
      t.string  :group_name,               :optional => true

      # Userfile attributes. If id is present it has priority;
      # otherwise the local name and type can be used.
      t.integer :userfile_id,              :optional => true
      t.string  :userfile_type,            :optional => true
      t.string  :userfile_name,            :optional => true

      t.string  :data_provider_id,         :optional => true
      t.string  :data_provider_type,       :optional => true
      t.string  :data_provider_name,       :optional => true

      # CbrainTask attributes. If id is present it has priority;
      # otherwise the locally stored attributes can be used.
      t.integer :cbrain_task_id,           :optional => true
      t.string  :cbrain_task_type,         :optional => true
      t.string  :cbrain_task_status,       :optional => true

      t.integer :remote_resource_id,       :optional => true
      t.string  :remote_resource_name,     :optional => true

      t.integer :tool_id,                  :optional => true
      t.string  :tool_name,                :optional => true

      t.integer :tool_config_id,           :optional => true
      t.string  :tool_config_version_name, :optional => true

      t.datetime :created_at,              :null     => false
    end
  end

end
