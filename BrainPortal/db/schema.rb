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

ActiveRecord::Schema.define(:version => 20090714184654) do

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
  end

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

  create_table "remote_resources", :force => true do |t|
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

  create_table "sessions", :force => true do |t|
    t.string   "session_id", :null => false
    t.text     "data"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "sessions", ["session_id"], :name => "index_sessions_on_session_id"
  add_index "sessions", ["updated_at"], :name => "index_sessions_on_updated_at"

  create_table "tags", :force => true do |t|
    t.string   "name"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

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
  end

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
  end

end
