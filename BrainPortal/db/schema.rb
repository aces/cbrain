# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20250225222958) do

  create_table "access_profiles", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci" do |t|
    t.string   "name",        null: false
    t.string   "description"
    t.string   "color"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
  end

  create_table "access_profiles_groups", id: false, force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci" do |t|
    t.integer "access_profile_id"
    t.integer "group_id"
  end

  create_table "access_profiles_users", id: false, force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci" do |t|
    t.integer "access_profile_id"
    t.integer "user_id"
  end

  create_table "active_record_logs", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci" do |t|
    t.integer  "ar_id"
    t.string   "ar_table_name"
    t.text     "log",           limit: 65535
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["ar_id", "ar_table_name"], name: "index_active_record_logs_on_ar_id_and_ar_table_name", using: :btree
  end

  create_table "background_activities", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci" do |t|
    t.string   "type",                                         null: false
    t.integer  "user_id"
    t.integer  "remote_resource_id"
    t.string   "status",                                       null: false
    t.string   "handler_lock"
    t.text     "items",              limit: 65535,             null: false
    t.integer  "current_item",                     default: 0
    t.integer  "num_successes",                    default: 0
    t.integer  "num_failures",                     default: 0
    t.text     "messages",           limit: 65535
    t.text     "options",            limit: 65535
    t.datetime "created_at",                                   null: false
    t.datetime "updated_at",                                   null: false
    t.datetime "start_at"
    t.string   "repeat"
    t.integer  "retry_count"
    t.integer  "retry_delay"
  end

  create_table "cbrain_tasks", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci" do |t|
    t.string   "type"
    t.integer  "batch_id"
    t.string   "cluster_jobid"
    t.string   "cluster_workdir"
    t.text     "params",                      limit: 65535
    t.string   "status"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "user_id"
    t.integer  "bourreau_id"
    t.text     "description",                 limit: 65535
    t.text     "prerequisites",               limit: 65535
    t.integer  "share_wd_tid"
    t.integer  "run_number"
    t.integer  "group_id"
    t.integer  "tool_config_id"
    t.integer  "level"
    t.integer  "rank"
    t.integer  "results_data_provider_id"
    t.decimal  "cluster_workdir_size",                      precision: 24
    t.boolean  "workdir_archived",                                         default: false, null: false
    t.integer  "workdir_archive_userfile_id"
    t.string   "zenodo_deposit_id"
    t.string   "zenodo_doi"
    t.index ["batch_id"], name: "index_cbrain_tasks_on_batch_id", using: :btree
    t.index ["bourreau_id", "status", "type"], name: "index_cbrain_tasks_on_bourreau_id_and_status_and_type", using: :btree
    t.index ["bourreau_id", "status"], name: "index_cbrain_tasks_on_bourreau_id_and_status", using: :btree
    t.index ["bourreau_id"], name: "index_cbrain_tasks_on_bourreau_id", using: :btree
    t.index ["cluster_workdir_size"], name: "index_cbrain_tasks_on_cluster_workdir_size", using: :btree
    t.index ["group_id", "bourreau_id", "status"], name: "index_cbrain_tasks_on_group_id_and_bourreau_id_and_status", using: :btree
    t.index ["group_id"], name: "index_cbrain_tasks_on_group_id", using: :btree
    t.index ["status"], name: "index_cbrain_tasks_on_status", using: :btree
    t.index ["tool_config_id"], name: "index_cbrain_tasks_on_tool_config_id", using: :btree
    t.index ["type"], name: "index_cbrain_tasks_on_type", using: :btree
    t.index ["user_id", "bourreau_id", "status"], name: "index_cbrain_tasks_on_user_id_and_bourreau_id_and_status", using: :btree
    t.index ["user_id"], name: "index_cbrain_tasks_on_user_id", using: :btree
    t.index ["workdir_archived"], name: "index_cbrain_tasks_on_workdir_archived", using: :btree
  end

  create_table "custom_filters", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci" do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "user_id"
    t.string   "type"
    t.text     "data",       limit: 65535
    t.index ["type"], name: "index_custom_filters_on_type", using: :btree
    t.index ["user_id"], name: "index_custom_filters_on_user_id", using: :btree
  end

  create_table "data_providers", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci" do |t|
    t.string   "name"
    t.string   "type"
    t.integer  "user_id"
    t.integer  "group_id"
    t.string   "remote_user"
    t.string   "remote_host"
    t.integer  "remote_port"
    t.string   "remote_dir"
    t.boolean  "online",                                         default: false, null: false
    t.boolean  "read_only",                                      default: false, null: false
    t.text     "description",                      limit: 65535
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "not_syncable",                                   default: false, null: false
    t.string   "time_zone"
    t.string   "cloud_storage_client_identifier"
    t.string   "cloud_storage_client_token"
    t.string   "alternate_host"
    t.string   "cloud_storage_client_bucket_name"
    t.string   "cloud_storage_client_path_start"
    t.string   "datalad_repository_url"
    t.string   "datalad_relative_path"
    t.string   "containerized_path"
    t.string   "cloud_storage_endpoint"
    t.string   "cloud_storage_region"
    t.index ["group_id"], name: "index_data_providers_on_group_id", using: :btree
    t.index ["type"], name: "index_data_providers_on_type", using: :btree
    t.index ["user_id"], name: "index_data_providers_on_user_id", using: :btree
  end

  create_table "data_usage", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci" do |t|
    t.integer  "user_id",                          null: false
    t.integer  "group_id",                         null: false
    t.string   "yearmonth",                        null: false
    t.integer  "views_count",          default: 0, null: false
    t.integer  "views_numfiles",       default: 0, null: false
    t.integer  "downloads_count",      default: 0, null: false
    t.integer  "downloads_numfiles",   default: 0, null: false
    t.integer  "task_setups_count",    default: 0, null: false
    t.integer  "task_setups_numfiles", default: 0, null: false
    t.integer  "copies_count",         default: 0, null: false
    t.integer  "copies_numfiles",      default: 0, null: false
    t.datetime "created_at",                       null: false
    t.datetime "updated_at",                       null: false
  end

  create_table "disk_quotas", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci" do |t|
    t.integer  "user_id"
    t.integer  "data_provider_id"
    t.decimal  "max_bytes",        precision: 24
    t.decimal  "max_files",        precision: 24
    t.datetime "created_at",                      null: false
    t.datetime "updated_at",                      null: false
  end

  create_table "exception_logs", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci" do |t|
    t.string   "exception_class"
    t.string   "request_controller"
    t.string   "request_action"
    t.string   "request_method"
    t.string   "request_format"
    t.integer  "user_id"
    t.text     "message",            limit: 65535
    t.text     "backtrace",          limit: 65535
    t.text     "request",            limit: 65535
    t.text     "session",            limit: 65535
    t.text     "request_headers",    limit: 65535
    t.string   "revision_no"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "groups", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci" do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "type"
    t.integer  "site_id"
    t.integer  "creator_id"
    t.boolean  "invisible",                    default: false
    t.text     "description",    limit: 65535
    t.boolean  "public",                       default: false
    t.boolean  "not_assignable",               default: false
    t.boolean  "track_usage",                  default: false, null: false
    t.index ["invisible"], name: "index_groups_on_invisible", using: :btree
    t.index ["name"], name: "index_groups_on_name", using: :btree
    t.index ["not_assignable"], name: "index_groups_on_not_assignable", using: :btree
    t.index ["public"], name: "index_groups_on_public", using: :btree
    t.index ["type"], name: "index_groups_on_type", using: :btree
  end

  create_table "groups_editors", id: false, force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci" do |t|
    t.integer "group_id"
    t.integer "user_id"
    t.index ["group_id", "user_id"], name: "index_groups_editors_on_group_id_and_user_id", unique: true, using: :btree
  end

  create_table "groups_users", id: false, force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci" do |t|
    t.integer "group_id"
    t.integer "user_id"
    t.index ["group_id"], name: "index_groups_users_on_group_id", using: :btree
    t.index ["user_id"], name: "index_groups_users_on_user_id", using: :btree
  end

  create_table "help_documents", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci" do |t|
    t.string   "key",        null: false
    t.string   "path",       null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_help_documents_on_key", unique: true, using: :btree
  end

  create_table "large_session_infos", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci" do |t|
    t.string   "session_id",                               null: false
    t.text     "data",       limit: 65535
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "user_id"
    t.boolean  "active",                   default: false
    t.index ["session_id"], name: "index_sessions_on_session_id", using: :btree
    t.index ["updated_at"], name: "index_sessions_on_updated_at", using: :btree
  end

  create_table "messages", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci" do |t|
    t.string   "header"
    t.text     "description",   limit: 65535
    t.text     "variable_text", limit: 65535
    t.string   "message_type"
    t.boolean  "read",                        default: false, null: false
    t.integer  "user_id"
    t.datetime "expiry"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "last_sent"
    t.boolean  "critical",                    default: false, null: false
    t.boolean  "display",                     default: false, null: false
    t.integer  "group_id"
    t.string   "type"
    t.boolean  "active"
    t.integer  "sender_id"
    t.index ["user_id"], name: "index_messages_on_user_id", using: :btree
  end

  create_table "meta_data_store", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci" do |t|
    t.integer  "ar_id"
    t.string   "ar_table_name"
    t.string   "meta_key"
    t.text     "meta_value",    limit: 65535
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["ar_id", "ar_table_name", "meta_key"], name: "index_meta_data_store_on_ar_id_and_ar_table_name_and_meta_key", using: :btree
    t.index ["ar_id", "ar_table_name"], name: "index_meta_data_store_on_ar_id_and_ar_table_name", using: :btree
    t.index ["ar_table_name", "meta_key"], name: "index_meta_data_store_on_ar_table_name_and_meta_key", using: :btree
    t.index ["meta_key"], name: "index_meta_data_store_on_meta_key", using: :btree
  end

  create_table "remote_resources", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci" do |t|
    t.string   "name"
    t.string   "type"
    t.integer  "user_id"
    t.integer  "group_id"
    t.boolean  "online",                                    default: false, null: false
    t.boolean  "read_only",                                 default: false, null: false
    t.text     "description",                 limit: 65535
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "ssh_control_user"
    t.string   "ssh_control_host"
    t.integer  "ssh_control_port"
    t.string   "ssh_control_rails_dir"
    t.string   "cache_md5"
    t.boolean  "portal_locked",                             default: false, null: false
    t.integer  "cache_trust_expire",                        default: 0
    t.datetime "time_of_death"
    t.string   "time_zone"
    t.string   "site_url_prefix"
    t.string   "nh_site_url_prefix"
    t.string   "dp_cache_dir"
    t.string   "dp_ignore_patterns"
    t.string   "cms_class"
    t.string   "cms_default_queue"
    t.string   "cms_extra_qsub_args"
    t.string   "cms_shared_dir"
    t.integer  "workers_instances"
    t.integer  "workers_chk_time"
    t.string   "workers_log_to"
    t.integer  "workers_verbose"
    t.string   "help_url"
    t.integer  "rr_timeout"
    t.string   "proxied_host"
    t.string   "support_email"
    t.string   "system_from_email"
    t.text     "email_delivery_options",      limit: 65535
    t.string   "nh_support_email"
    t.string   "nh_system_from_email"
    t.string   "external_status_page_url"
    t.string   "docker_executable_name"
    t.string   "singularity_executable_name"
    t.string   "small_logo"
    t.string   "large_logo"
    t.index ["type"], name: "index_remote_resources_on_type", using: :btree
  end

  create_table "resource_usage", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci" do |t|
    t.string   "type"
    t.decimal  "value",                    precision: 24
    t.integer  "user_id"
    t.string   "user_type"
    t.string   "user_login"
    t.integer  "group_id"
    t.string   "group_type"
    t.string   "group_name"
    t.integer  "userfile_id"
    t.string   "userfile_type"
    t.string   "userfile_name"
    t.integer  "data_provider_id"
    t.string   "data_provider_type"
    t.string   "data_provider_name"
    t.integer  "cbrain_task_id"
    t.string   "cbrain_task_type"
    t.string   "cbrain_task_status"
    t.integer  "remote_resource_id"
    t.string   "remote_resource_name"
    t.integer  "tool_id"
    t.string   "tool_name"
    t.integer  "tool_config_id"
    t.string   "tool_config_version_name"
    t.datetime "created_at",                              null: false
    t.index ["type", "cbrain_task_id"], name: "index_resource_usage_on_type_and_cbrain_task_id", using: :btree
    t.index ["type", "cbrain_task_status"], name: "index_resource_usage_on_type_and_cbrain_task_status", using: :btree
    t.index ["type", "cbrain_task_type"], name: "index_resource_usage_on_type_and_cbrain_task_type", using: :btree
    t.index ["type", "data_provider_id"], name: "index_resource_usage_on_type_and_data_provider_id", using: :btree
    t.index ["type", "data_provider_name"], name: "index_resource_usage_on_type_and_data_provider_name", using: :btree
    t.index ["type", "data_provider_type"], name: "index_resource_usage_on_type_and_data_provider_type", using: :btree
    t.index ["type", "group_id"], name: "index_resource_usage_on_type_and_group_id", using: :btree
    t.index ["type", "group_name"], name: "index_resource_usage_on_type_and_group_name", using: :btree
    t.index ["type", "group_type"], name: "index_resource_usage_on_type_and_group_type", using: :btree
    t.index ["type", "remote_resource_id"], name: "index_resource_usage_on_type_and_remote_resource_id", using: :btree
    t.index ["type", "remote_resource_name"], name: "index_resource_usage_on_type_and_remote_resource_name", using: :btree
    t.index ["type", "tool_config_id"], name: "index_resource_usage_on_type_and_tool_config_id", using: :btree
    t.index ["type", "tool_config_version_name"], name: "index_resource_usage_on_type_and_tool_config_version_name", using: :btree
    t.index ["type", "tool_id"], name: "index_resource_usage_on_type_and_tool_id", using: :btree
    t.index ["type", "tool_name"], name: "index_resource_usage_on_type_and_tool_name", using: :btree
    t.index ["type", "user_id"], name: "index_resource_usage_on_type_and_user_id", using: :btree
    t.index ["type", "user_login"], name: "index_resource_usage_on_type_and_user_login", using: :btree
    t.index ["type", "user_type"], name: "index_resource_usage_on_type_and_user_type", using: :btree
    t.index ["type", "userfile_id"], name: "index_resource_usage_on_type_and_userfile_id", using: :btree
    t.index ["type", "userfile_name"], name: "index_resource_usage_on_type_and_userfile_name", using: :btree
    t.index ["type", "userfile_type"], name: "index_resource_usage_on_type_and_userfile_type", using: :btree
    t.index ["type"], name: "index_resource_usage_on_type", using: :btree
  end

  create_table "sanity_checks", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci" do |t|
    t.string   "revision_info"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "signups", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci" do |t|
    t.string   "title"
    t.string   "first",                                            null: false
    t.string   "middle"
    t.string   "last",                                             null: false
    t.string   "institution",                                      null: false
    t.string   "department"
    t.string   "position"
    t.string   "affiliation"
    t.string   "email",                                            null: false
    t.string   "website"
    t.string   "street1"
    t.string   "street2"
    t.string   "city"
    t.string   "province"
    t.string   "country"
    t.string   "postal_code"
    t.string   "time_zone"
    t.string   "service"
    t.string   "login"
    t.text     "comment",            limit: 65535
    t.string   "session_id"
    t.string   "confirm_token"
    t.boolean  "confirmed"
    t.string   "approved_by"
    t.datetime "approved_at"
    t.datetime "created_at",                                       null: false
    t.datetime "updated_at",                                       null: false
    t.text     "admin_comment",      limit: 65535
    t.integer  "user_id"
    t.boolean  "hidden",                           default: false
    t.integer  "remote_resource_id"
    t.string   "form_page"
  end

  create_table "sites", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci" do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "description", limit: 65535
  end

  create_table "ssh_agent_unlocking_events", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci" do |t|
    t.string   "message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "sync_status", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci" do |t|
    t.integer  "userfile_id"
    t.integer  "remote_resource_id"
    t.string   "status"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "accessed_at"
    t.datetime "synced_at"
    t.index ["remote_resource_id"], name: "index_sync_status_on_remote_resource_id", using: :btree
    t.index ["userfile_id", "remote_resource_id"], name: "index_sync_status_on_userfile_id_and_remote_resource_id", unique: true, using: :btree
    t.index ["userfile_id"], name: "index_sync_status_on_userfile_id", using: :btree
  end

  create_table "tags", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci" do |t|
    t.string   "name"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "group_id"
    t.index ["name"], name: "index_tags_on_name", using: :btree
    t.index ["user_id"], name: "index_tags_on_user_id", using: :btree
  end

  create_table "tags_userfiles", id: false, force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci" do |t|
    t.integer "tag_id"
    t.integer "userfile_id"
    t.index ["tag_id"], name: "index_tags_userfiles_on_tag_id", using: :btree
    t.index ["userfile_id"], name: "index_tags_userfiles_on_userfile_id", using: :btree
  end

  create_table "tool_configs", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci" do |t|
    t.string   "version_name"
    t.text     "description",                   limit: 65535
    t.integer  "tool_id"
    t.integer  "bourreau_id"
    t.text     "env_array",                     limit: 65535
    t.text     "script_prologue",               limit: 65535
    t.text     "script_epilogue",               limit: 65535
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "group_id"
    t.integer  "ncpus"
    t.string   "extra_qsub_args"
    t.integer  "container_image_userfile_id"
    t.string   "containerhub_image_name"
    t.string   "container_engine"
    t.string   "container_index_location"
    t.text     "singularity_overlays_specs",    limit: 65535
    t.boolean  "singularity_use_short_workdir",               default: false, null: false
    t.string   "container_exec_args"
    t.boolean  "inputs_readonly",                             default: false
    t.string   "boutiques_descriptor_path"
    t.index ["bourreau_id"], name: "index_tool_configs_on_bourreau_id", using: :btree
    t.index ["tool_id"], name: "index_tool_configs_on_tool_id", using: :btree
  end

  create_table "tools", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci" do |t|
    t.string   "name"
    t.integer  "user_id"
    t.integer  "group_id"
    t.string   "category"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "cbrain_task_class_name"
    t.string   "select_menu_text"
    t.text     "description",              limit: 65535
    t.string   "url"
    t.string   "application_package_name"
    t.string   "application_type"
    t.string   "application_tags"
    t.index ["category"], name: "index_tools_on_category", using: :btree
    t.index ["cbrain_task_class_name"], name: "index_tools_on_cbrain_task_class", using: :btree
    t.index ["group_id"], name: "index_tools_on_group_id", using: :btree
    t.index ["user_id"], name: "index_tools_on_user_id", using: :btree
  end

  create_table "userfiles", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci" do |t|
    t.string   "name"
    t.decimal  "size",                            precision: 24
    t.integer  "user_id"
    t.integer  "parent_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "type"
    t.integer  "group_id"
    t.integer  "data_provider_id"
    t.boolean  "group_writable",                                 default: false, null: false
    t.integer  "num_files"
    t.boolean  "hidden",                                         default: false, null: false
    t.boolean  "immutable",                                      default: false, null: false
    t.boolean  "archived",                                       default: false, null: false
    t.text     "description",       limit: 65535
    t.string   "zenodo_deposit_id"
    t.string   "zenodo_doi"
    t.string   "browse_path"
    t.index ["archived", "id"], name: "index_userfiles_on_archived_and_id", using: :btree
    t.index ["data_provider_id", "browse_path"], name: "index_userfiles_on_data_provider_id_and_browse_path", using: :btree
    t.index ["data_provider_id"], name: "index_userfiles_on_data_provider_id", using: :btree
    t.index ["group_id"], name: "index_userfiles_on_group_id", using: :btree
    t.index ["hidden", "id"], name: "index_userfiles_on_hidden_and_id", using: :btree
    t.index ["hidden"], name: "index_userfiles_on_hidden", using: :btree
    t.index ["immutable", "id"], name: "index_userfiles_on_immutable_and_id", using: :btree
    t.index ["name"], name: "index_userfiles_on_name", using: :btree
    t.index ["type"], name: "index_userfiles_on_type", using: :btree
    t.index ["user_id"], name: "index_userfiles_on_user_id", using: :btree
  end

  create_table "users", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci" do |t|
    t.string   "full_name"
    t.string   "position"
    t.string   "affiliation"
    t.string   "login"
    t.string   "email"
    t.string   "type"
    t.string   "crypted_password"
    t.string   "salt"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "site_id"
    t.boolean  "password_reset",       default: false, null: false
    t.string   "time_zone"
    t.string   "city"
    t.string   "country"
    t.datetime "last_connected_at"
    t.boolean  "account_locked",       default: false, null: false
    t.string   "zenodo_main_token"
    t.string   "zenodo_sandbox_token"
    t.index ["login"], name: "index_users_on_login", using: :btree
    t.index ["type"], name: "index_users_on_type", using: :btree
  end

end
