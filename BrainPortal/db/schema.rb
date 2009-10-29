# This file is auto-generated from the current state of the database. Instead of editing this file, 
# please use the migrations feature of Active Record to incrementally modify your database, and
# then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your database schema. If you need
# to create the application database on another system, you should be using db:schema:load, not running
# all the migrations from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20091029172745) do

  create_table "active_record_logs", :force => true do |t|
    t.integer  "ar_id"
    t.string   "ar_class"
    t.text     "log"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "active_record_logs", ["ar_id", "ar_class"], :name => "index_active_record_logs_on_ar_id_and_ar_class"

  create_table "custom_filters", :force => true do |t|
    t.string   "name"
    t.string   "file_name_type"
    t.string   "file_name_term"
    t.string   "created_date_type"
    t.datetime "created_date_term"
    t.string   "size_type"
    t.integer  "size_term"
    t.integer  "group_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "user_id"
    t.text     "tags"
  end

  add_index "custom_filters", ["user_id"], :name => "index_custom_filters_on_user_id"

  create_table "data_providers", :force => true do |t|
    t.string   "name"
    t.string   "type"
    t.integer  "user_id"
    t.integer  "group_id"
    t.string   "remote_user"
    t.string   "remote_host"
    t.integer  "remote_port"
    t.string   "remote_dir"
    t.boolean  "online"
    t.boolean  "read_only"
    t.string   "description"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "drmaa_tasks", :force => true do |t|
    t.string   "type"
    t.string   "drmaa_jobid"
    t.string   "drmaa_workdir"
    t.text     "params"
    t.string   "status"
    t.text     "log"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "user_id"
    t.integer  "bourreau_id"
    t.text     "description"
  end

  create_table "feedbacks", :force => true do |t|
    t.string   "summary"
    t.text     "details"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "user_id"
  end

  create_table "groups", :force => true do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "type"
    t.integer  "site_id"
  end

  add_index "groups", ["name"], :name => "index_groups_on_name"
  add_index "groups", ["type"], :name => "index_groups_on_type"

  create_table "groups_users", :id => false, :force => true do |t|
    t.integer "group_id"
    t.integer "user_id"
  end

  create_table "logged_exceptions", :force => true do |t|
    t.string   "exception_class"
    t.string   "controller_name"
    t.string   "action_name"
    t.text     "message"
    t.text     "backtrace"
    t.text     "environment"
    t.text     "request"
    t.datetime "created_at"
  end

  create_table "messages", :force => true do |t|
    t.string   "header"
    t.text     "description"
    t.text     "variable_text"
    t.string   "message_type"
    t.boolean  "read"
    t.integer  "user_id"
    t.datetime "expiry"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "last_sent"
    t.boolean  "critical"
    t.boolean  "display"
  end

  create_table "remote_resources", :force => true do |t|
    t.string   "name"
    t.string   "type"
    t.integer  "user_id"
    t.integer  "group_id"
    t.string   "actres_user"
    t.string   "actres_host"
    t.integer  "actres_port"
    t.string   "actres_dir"
    t.boolean  "online"
    t.boolean  "read_only"
    t.string   "description"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "ssh_control_user"
    t.string   "ssh_control_host"
    t.integer  "ssh_control_port"
    t.string   "ssh_control_rails_dir"
    t.integer  "tunnel_mysql_port"
    t.integer  "tunnel_actres_port"
    t.string   "cache_md5"
  end

  add_index "remote_resources", ["type"], :name => "index_remote_resources_on_type"

  create_table "sessions", :force => true do |t|
    t.string   "session_id", :null => false
    t.text     "data"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "sessions", ["session_id"], :name => "index_sessions_on_session_id"
  add_index "sessions", ["updated_at"], :name => "index_sessions_on_updated_at"

  create_table "sites", :force => true do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "sync_status", :force => true do |t|
    t.integer  "userfile_id"
    t.integer  "remote_resource_id"
    t.string   "status"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "sync_status", ["remote_resource_id"], :name => "index_sync_status_on_remote_resource_id"
  add_index "sync_status", ["userfile_id", "remote_resource_id"], :name => "index_sync_status_on_userfile_id_and_remote_resource_id"
  add_index "sync_status", ["userfile_id"], :name => "index_sync_status_on_userfile_id"

  create_table "tags", :force => true do |t|
    t.string   "name"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "tags", ["name"], :name => "index_tags_on_name"

  create_table "tags_userfiles", :id => false, :force => true do |t|
    t.integer "tag_id"
    t.integer "userfile_id"
  end

  create_table "user_preferences", :force => true do |t|
    t.integer  "user_id"
    t.integer  "data_provider_id"
    t.text     "other_options"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "bourreau_id"
  end

  add_index "user_preferences", ["user_id"], :name => "index_user_preferences_on_user_id"

  create_table "userfiles", :force => true do |t|
    t.string   "name"
    t.integer  "size"
    t.integer  "user_id"
    t.integer  "parent_id"
    t.integer  "lft"
    t.integer  "rgt"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "type"
    t.string   "task"
    t.integer  "group_id"
    t.integer  "data_provider_id"
    t.boolean  "group_writable",   :default => false
    t.integer  "num_files"
  end

  add_index "userfiles", ["data_provider_id"], :name => "index_userfiles_on_data_provider_id"
  add_index "userfiles", ["name"], :name => "index_userfiles_on_name"
  add_index "userfiles", ["type"], :name => "index_userfiles_on_type"
  add_index "userfiles", ["user_id"], :name => "index_userfiles_on_user_id"

  create_table "users", :force => true do |t|
    t.string   "full_name"
    t.string   "login"
    t.string   "email"
    t.string   "crypted_password",          :limit => 40
    t.string   "salt",                      :limit => 40
    t.string   "remember_token"
    t.datetime "remember_token_expires_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "role"
    t.integer  "site_id"
  end

  add_index "users", ["login"], :name => "index_users_on_login"
  add_index "users", ["role"], :name => "index_users_on_role"

end
