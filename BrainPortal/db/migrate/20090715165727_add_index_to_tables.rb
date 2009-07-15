class AddIndexToTables < ActiveRecord::Migration
  def self.up

    add_index :users,            :login
    add_index :users,            :role

    add_index :userfiles,        :name
    add_index :userfiles,        :user_id
    add_index :userfiles,        :type
    add_index :userfiles,        :data_provider_id

    add_index :groups,           :name
    add_index :groups,           :type

    add_index :remote_resources, :type

    add_index :tags,             :name

    add_index :user_preferences, :user_id

    add_index :custom_filters,   :user_id

  end

  def self.down

    remove_index :users,            :login
    remove_index :users,            :role

    remove_index :userfiles,        :name
    remove_index :userfiles,        :user_id
    remove_index :userfiles,        :type
    remove_index :userfiles,        :data_provider_id

    remove_index :groups,           :name
    remove_index :groups,           :type

    remove_index :remote_resources, :type

    remove_index :tags,             :name

    remove_index :user_preferences, :user_id

    remove_index :custom_filters,   :user_id

  end
end
