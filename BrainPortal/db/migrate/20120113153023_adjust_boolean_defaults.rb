class AdjustBooleanDefaults < ActiveRecord::Migration
  def self.up
    change_column :cbrain_tasks,     :workdir_archived, :boolean, :default => false, :null => false

    change_column :data_providers,   :online,           :boolean, :default => false, :null => false
    change_column :data_providers,   :read_only,        :boolean, :default => false, :null => false
    change_column :data_providers,   :not_syncable,     :boolean, :default => false, :null => false

    change_column :messages,         :read,             :boolean, :default => false, :null => false
    change_column :messages,         :critical,         :boolean, :default => false, :null => false
    change_column :messages,         :display,          :boolean, :default => false, :null => false

    change_column :remote_resources, :online,           :boolean, :default => false, :null => false
    change_column :remote_resources, :read_only,        :boolean, :default => false, :null => false
    change_column :remote_resources, :portal_locked,    :boolean, :default => false, :null => false

    change_column :sessions,         :active,           :boolean, :default => false, :null => false

    change_column :userfiles,        :group_writable,   :boolean, :default => false, :null => false

    change_column :users,            :password_reset,   :boolean, :default => false, :null => false
    change_column :users,            :account_locked,   :boolean, :default => false, :null => false
  end

  def self.down
    change_column :cbrain_tasks,     :workdir_archived, :boolean, :default => nil,   :null => true

    change_column :data_providers,   :online,           :boolean, :default => nil,   :null => true
    change_column :data_providers,   :read_only,        :boolean, :default => nil,   :null => true
    change_column :data_providers,   :not_syncable,     :boolean, :default => false, :null => true

    change_column :messages,         :read,             :boolean, :default => nil,   :null => true
    change_column :messages,         :critical,         :boolean, :default => nil,   :null => true
    change_column :messages,         :display,          :boolean, :default => nil,   :null => true

    change_column :remote_resources, :online,           :boolean, :default => nil,   :null => true
    change_column :remote_resources, :read_only,        :boolean, :default => nil,   :null => true
    change_column :remote_resources, :portal_locked,    :boolean, :default => nil,   :null => true

    change_column :sessions,         :active,           :boolean, :default => nil,   :null => true

    change_column :userfiles,        :group_writable,   :boolean, :default => false, :null => true

    change_column :users,            :password_reset,   :boolean, :default => nil,   :null => true
    change_column :users,            :account_locked,   :boolean, :default => nil,   :null => true
  end

end

