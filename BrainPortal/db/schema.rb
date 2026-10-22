# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_20_164439) do
  create_table "access_profiles", id: :integer, charset: "utf8mb3", collation: "utf8mb3_unicode_ci", force: :cascade do |t|
    t.string "name", null: false
    t.string "description"
    t.string "color"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "access_profiles_groups", id: false, charset: "utf8mb3", collation: "utf8mb3_unicode_ci", force: :cascade do |t|
    t.integer "access_profile_id"
    t.integer "group_id"
  end

  create_table "access_profiles_users", id: false, charset: "utf8mb3", collation: "utf8mb3_unicode_ci", force: :cascade do |t|
    t.integer "access_profile_id"
    t.integer "user_id"
  end

  create_table "active_record_logs", id: :integer, charset: "utf8mb3", collation: "utf8mb3_unicode_ci", force: :cascade do |t|
    t.integer "ar_id"
    t.string "ar_table_name"
    t.datetime "created_at", precision: nil
    t.text "log"
    t.datetime "updated_at", precision: nil
    t.index ["ar_id", "ar_table_name"], name: "index_active_record_logs_on_ar_id_and_ar_table_name"
  end

  create_table "background_activities", id: :integer, charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.integer "current_item", default: 0
    t.string "handler_lock"
    t.text "items", null: false
    t.text "messages"
    t.integer "num_failures", default: 0
    t.integer "num_successes", default: 0
    t.text "options"
    t.integer "remote_resource_id"
    t.string "repeat"
    t.integer "retry_count"
    t.integer "retry_delay"
    t.datetime "start_at", precision: nil
    t.string "status", null: false
    t.string "type", null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "user_id"
  end

  create_table "cbrain_tasks", id: :integer, charset: "utf8mb3", collation: "utf8mb3_unicode_ci", force: :cascade do |t|
    t.integer "batch_id"
    t.integer "bourreau_id"
    t.string "cluster_jobid"
    t.string "cluster_workdir"
    t.decimal "cluster_workdir_size", precision: 24
    t.datetime "created_at", precision: nil
    t.text "description"
    t.integer "group_id"
    t.integer "level"
    t.text "params"
    t.text "prerequisites"
    t.integer "rank"
    t.integer "results_data_provider_id"
    t.integer "run_number"
    t.integer "share_wd_tid"
    t.string "status"
    t.integer "tool_config_id"
    t.string "type"
    t.datetime "updated_at", precision: nil
    t.integer "user_id"
    t.integer "workdir_archive_userfile_id"
    t.boolean "workdir_archived", default: false, null: false
    t.string "zenodo_deposit_id"
    t.string "zenodo_doi"
    t.index ["batch_id"], name: "index_cbrain_tasks_on_batch_id"
    t.index ["bourreau_id", "status", "type"], name: "index_cbrain_tasks_on_bourreau_id_and_status_and_type"
    t.index ["bourreau_id", "status"], name: "index_cbrain_tasks_on_bourreau_id_and_status"
    t.index ["bourreau_id"], name: "index_cbrain_tasks_on_bourreau_id"
    t.index ["cluster_workdir_size"], name: "index_cbrain_tasks_on_cluster_workdir_size"
    t.index ["group_id", "bourreau_id", "status"], name: "index_cbrain_tasks_on_group_id_and_bourreau_id_and_status"
    t.index ["group_id"], name: "index_cbrain_tasks_on_group_id"
    t.index ["status"], name: "index_cbrain_tasks_on_status"
    t.index ["tool_config_id"], name: "index_cbrain_tasks_on_tool_config_id"
    t.index ["type"], name: "index_cbrain_tasks_on_type"
    t.index ["user_id", "bourreau_id", "status"], name: "index_cbrain_tasks_on_user_id_and_bourreau_id_and_status"
    t.index ["user_id"], name: "index_cbrain_tasks_on_user_id"
    t.index ["workdir_archived"], name: "index_cbrain_tasks_on_workdir_archived"
  end

  create_table "custom_filters", id: :integer, charset: "utf8mb3", collation: "utf8mb3_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.text "data"
    t.string "name"
    t.string "type"
    t.datetime "updated_at", precision: nil
    t.integer "user_id"
    t.index ["type"], name: "index_custom_filters_on_type"
    t.index ["user_id"], name: "index_custom_filters_on_user_id"
  end

  create_table "data_providers", id: :integer, charset: "utf8mb3", collation: "utf8mb3_unicode_ci", force: :cascade do |t|
    t.string "alternate_host"
    t.string "cloud_storage_client_bucket_name"
    t.string "cloud_storage_client_identifier"
    t.string "cloud_storage_client_path_start"
    t.string "cloud_storage_client_token"
    t.string "cloud_storage_endpoint"
    t.string "cloud_storage_region"
    t.string "containerized_path"
    t.datetime "created_at", precision: nil
    t.string "datalad_relative_path"
    t.string "datalad_repository_url"
    t.text "description"
    t.integer "group_id"
    t.string "name"
    t.boolean "not_syncable", default: false, null: false
    t.boolean "online", default: false, null: false
    t.boolean "read_only", default: false, null: false
    t.string "remote_dir"
    t.string "remote_host"
    t.integer "remote_port"
    t.string "remote_user"
    t.string "time_zone"
    t.string "type"
    t.datetime "updated_at", precision: nil
    t.integer "user_id"
    t.index ["group_id"], name: "index_data_providers_on_group_id"
    t.index ["type"], name: "index_data_providers_on_type"
    t.index ["user_id"], name: "index_data_providers_on_user_id"
  end

  create_table "data_usage", id: :integer, charset: "utf8mb3", collation: "utf8mb3_unicode_ci", force: :cascade do |t|
    t.integer "copies_count", default: 0, null: false
    t.integer "copies_numfiles", default: 0, null: false
    t.datetime "created_at", precision: nil, null: false
    t.integer "downloads_count", default: 0, null: false
    t.integer "downloads_numfiles", default: 0, null: false
    t.integer "group_id", null: false
    t.integer "task_setups_count", default: 0, null: false
    t.integer "task_setups_numfiles", default: 0, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "user_id", null: false
    t.integer "views_count", default: 0, null: false
    t.integer "views_numfiles", default: 0, null: false
    t.string "yearmonth", null: false
  end

  create_table "exception_logs", id: :integer, charset: "utf8mb3", collation: "utf8mb3_unicode_ci", force: :cascade do |t|
    t.text "backtrace"
    t.datetime "created_at", precision: nil
    t.string "exception_class"
    t.text "message"
    t.text "request"
    t.string "request_action"
    t.string "request_controller"
    t.string "request_format"
    t.text "request_headers"
    t.string "request_method"
    t.string "revision_no"
    t.text "session"
    t.datetime "updated_at", precision: nil
    t.integer "user_id"
  end

  create_table "groups", id: :integer, charset: "utf8mb3", collation: "utf8mb3_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.integer "creator_id"
    t.text "description"
    t.boolean "invisible", default: false
    t.string "name"
    t.boolean "not_assignable", default: false
    t.boolean "public", default: false
    t.integer "site_id"
    t.boolean "track_usage", default: false, null: false
    t.string "type"
    t.datetime "updated_at", precision: nil
    t.index ["invisible"], name: "index_groups_on_invisible"
    t.index ["name"], name: "index_groups_on_name"
    t.index ["not_assignable"], name: "index_groups_on_not_assignable"
    t.index ["public"], name: "index_groups_on_public"
    t.index ["type"], name: "index_groups_on_type"
  end

  create_table "groups_editors", id: false, charset: "utf8mb3", collation: "utf8mb3_unicode_ci", force: :cascade do |t|
    t.integer "group_id"
    t.integer "user_id"
    t.index ["group_id", "user_id"], name: "index_groups_editors_on_group_id_and_user_id", unique: true
  end

  create_table "groups_users", id: false, charset: "utf8mb3", collation: "utf8mb3_unicode_ci", force: :cascade do |t|
    t.integer "group_id"
    t.integer "user_id"
    t.index ["group_id"], name: "index_groups_users_on_group_id"
    t.index ["user_id"], name: "index_groups_users_on_user_id"
  end

  create_table "help_documents", id: :integer, charset: "utf8mb3", collation: "utf8mb3_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.string "key", null: false
    t.string "path", null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["key"], name: "index_help_documents_on_key", unique: true
  end

  create_table "large_session_infos", id: :integer, charset: "utf8mb3", collation: "utf8mb3_unicode_ci", force: :cascade do |t|
    t.boolean "active", default: false
    t.datetime "created_at", precision: nil
    t.text "data"
    t.string "session_id", null: false
    t.datetime "updated_at", precision: nil
    t.integer "user_id"
    t.index ["session_id"], name: "index_sessions_on_session_id"
    t.index ["updated_at"], name: "index_sessions_on_updated_at"
  end

  create_table "messages", id: :integer, charset: "utf8mb3", collation: "utf8mb3_unicode_ci", force: :cascade do |t|
    t.boolean "active"
    t.datetime "created_at", precision: nil
    t.boolean "critical", default: false, null: false
    t.text "description"
    t.boolean "display", default: false, null: false
    t.datetime "expiry", precision: nil
    t.string "header"
    t.integer "invitation_group_id"
    t.datetime "last_sent", precision: nil
    t.string "message_type"
    t.boolean "read", default: false, null: false
    t.integer "sender_id"
    t.string "type"
    t.datetime "updated_at", precision: nil
    t.integer "user_id"
    t.text "variable_text"
    t.index ["user_id"], name: "index_messages_on_user_id"
  end

  create_table "meta_data_store", id: :integer, charset: "utf8mb3", collation: "utf8mb3_unicode_ci", force: :cascade do |t|
    t.integer "ar_id"
    t.string "ar_table_name"
    t.datetime "created_at", precision: nil
    t.string "meta_key"
    t.text "meta_value"
    t.datetime "updated_at", precision: nil
    t.index ["ar_id", "ar_table_name", "meta_key"], name: "index_meta_data_store_on_ar_id_and_ar_table_name_and_meta_key"
    t.index ["ar_id", "ar_table_name"], name: "index_meta_data_store_on_ar_id_and_ar_table_name"
    t.index ["ar_table_name", "meta_key"], name: "index_meta_data_store_on_ar_table_name_and_meta_key"
    t.index ["meta_key"], name: "index_meta_data_store_on_meta_key"
  end

  create_table "quotas", id: :integer, charset: "utf8mb3", collation: "utf8mb3_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.integer "data_provider_id"
    t.integer "group_id"
    t.integer "max_active_tasks"
    t.decimal "max_bytes", precision: 24
    t.decimal "max_cpu_ever", precision: 24
    t.decimal "max_cpu_past_month", precision: 24
    t.decimal "max_cpu_past_week", precision: 24
    t.decimal "max_files", precision: 24
    t.integer "remote_resource_id"
    t.string "type"
    t.datetime "updated_at", precision: nil, null: false
    t.integer "user_id"
  end

  create_table "remote_resources", id: :integer, charset: "utf8mb3", collation: "utf8mb3_unicode_ci", force: :cascade do |t|
    t.integer "active_resource_control_port"
    t.integer "activity_workers_instances", default: 1, null: false
    t.string "cache_md5"
    t.integer "cache_trust_expire", default: 0
    t.string "cms_class"
    t.string "cms_default_queue"
    t.string "cms_extra_qsub_args"
    t.string "cms_shared_dir"
    t.datetime "created_at", precision: nil
    t.text "description"
    t.string "docker_executable_name"
    t.string "dp_cache_dir"
    t.string "dp_ignore_patterns"
    t.text "email_delivery_options"
    t.string "external_status_page_url"
    t.integer "group_id"
    t.string "help_url"
    t.string "jumphost_host"
    t.integer "jumphost_port"
    t.string "jumphost_user"
    t.string "large_logo"
    t.string "name"
    t.string "nh_site_url_prefix"
    t.string "nh_support_email"
    t.string "nh_system_from_email"
    t.boolean "online", default: false, null: false
    t.boolean "portal_locked", default: false, null: false
    t.boolean "read_only", default: false, null: false
    t.string "reverse_service_db_socket_path"
    t.string "reverse_service_host"
    t.string "reverse_service_port"
    t.string "reverse_service_ssh_agent_socket_path"
    t.string "reverse_service_user"
    t.integer "rr_timeout"
    t.string "singularity_executable_name"
    t.string "site_url_prefix"
    t.string "small_logo"
    t.string "ssh_control_host"
    t.integer "ssh_control_port"
    t.string "ssh_control_rails_dir"
    t.string "ssh_control_user"
    t.string "support_email"
    t.string "system_from_email"
    t.string "time_zone"
    t.string "type"
    t.datetime "updated_at", precision: nil
    t.boolean "use_reverse_service", default: false, null: false
    t.integer "user_id"
    t.integer "workers_chk_time"
    t.integer "workers_instances"
    t.string "workers_log_to"
    t.integer "workers_verbose"
    t.index ["type"], name: "index_remote_resources_on_type"
  end

  create_table "resource_usage", id: :integer, charset: "utf8mb3", collation: "utf8mb3_unicode_ci", force: :cascade do |t|
    t.integer "cbrain_task_id"
    t.string "cbrain_task_status"
    t.string "cbrain_task_type"
    t.datetime "created_at", precision: nil, null: false
    t.integer "data_provider_id"
    t.string "data_provider_name"
    t.string "data_provider_type"
    t.integer "group_id"
    t.string "group_name"
    t.string "group_type"
    t.integer "remote_resource_id"
    t.string "remote_resource_name"
    t.integer "tool_config_id"
    t.string "tool_config_version_name"
    t.integer "tool_id"
    t.string "tool_name"
    t.string "type"
    t.integer "user_id"
    t.string "user_login"
    t.string "user_type"
    t.integer "userfile_id"
    t.string "userfile_name"
    t.string "userfile_type"
    t.decimal "value", precision: 24
    t.index ["type", "cbrain_task_id"], name: "index_resource_usage_on_type_and_cbrain_task_id"
    t.index ["type", "cbrain_task_status"], name: "index_resource_usage_on_type_and_cbrain_task_status"
    t.index ["type", "cbrain_task_type"], name: "index_resource_usage_on_type_and_cbrain_task_type"
    t.index ["type", "data_provider_id"], name: "index_resource_usage_on_type_and_data_provider_id"
    t.index ["type", "data_provider_name"], name: "index_resource_usage_on_type_and_data_provider_name"
    t.index ["type", "data_provider_type"], name: "index_resource_usage_on_type_and_data_provider_type"
    t.index ["type", "group_id"], name: "index_resource_usage_on_type_and_group_id"
    t.index ["type", "group_name"], name: "index_resource_usage_on_type_and_group_name"
    t.index ["type", "group_type"], name: "index_resource_usage_on_type_and_group_type"
    t.index ["type", "remote_resource_id"], name: "index_resource_usage_on_type_and_remote_resource_id"
    t.index ["type", "remote_resource_name"], name: "index_resource_usage_on_type_and_remote_resource_name"
    t.index ["type", "tool_config_id"], name: "index_resource_usage_on_type_and_tool_config_id"
    t.index ["type", "tool_config_version_name"], name: "index_resource_usage_on_type_and_tool_config_version_name"
    t.index ["type", "tool_id"], name: "index_resource_usage_on_type_and_tool_id"
    t.index ["type", "tool_name"], name: "index_resource_usage_on_type_and_tool_name"
    t.index ["type", "user_id"], name: "index_resource_usage_on_type_and_user_id"
    t.index ["type", "user_login"], name: "index_resource_usage_on_type_and_user_login"
    t.index ["type", "user_type"], name: "index_resource_usage_on_type_and_user_type"
    t.index ["type", "userfile_id"], name: "index_resource_usage_on_type_and_userfile_id"
    t.index ["type", "userfile_name"], name: "index_resource_usage_on_type_and_userfile_name"
    t.index ["type", "userfile_type"], name: "index_resource_usage_on_type_and_userfile_type"
    t.index ["type"], name: "index_resource_usage_on_type"
  end

  create_table "sanity_checks", id: :integer, charset: "utf8mb3", collation: "utf8mb3_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.string "revision_info"
    t.datetime "updated_at", precision: nil
  end

  create_table "signups", id: :integer, charset: "utf8mb3", collation: "utf8mb3_unicode_ci", force: :cascade do |t|
    t.text "admin_comment"
    t.string "affiliation"
    t.datetime "approved_at", precision: nil
    t.string "approved_by"
    t.string "city"
    t.text "comment"
    t.string "confirm_token"
    t.boolean "confirmed"
    t.string "country"
    t.datetime "created_at", precision: nil, null: false
    t.string "department"
    t.string "email", null: false
    t.string "first", null: false
    t.string "form_page"
    t.boolean "hidden", default: false
    t.string "institution", null: false
    t.string "last", null: false
    t.string "login"
    t.string "middle"
    t.string "position"
    t.string "postal_code"
    t.string "province"
    t.integer "remote_resource_id"
    t.string "service"
    t.string "session_id"
    t.string "street1"
    t.string "street2"
    t.string "time_zone"
    t.string "title"
    t.datetime "updated_at", precision: nil, null: false
    t.integer "user_id"
    t.string "website"
  end

  create_table "sites", id: :integer, charset: "utf8mb3", collation: "utf8mb3_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.text "description"
    t.string "name"
    t.datetime "updated_at", precision: nil
  end

  create_table "solid_cable_messages", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.binary "channel", limit: 1024, null: false
    t.bigint "channel_hash", null: false
    t.datetime "created_at", null: false
    t.binary "payload", size: :long, null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_cache_entries", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.integer "byte_size", null: false
    t.datetime "created_at", null: false
    t.binary "key", limit: 1024, null: false
    t.bigint "key_hash", null: false
    t.binary "value", size: :long, null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "solid_queue_blocked_executions", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "ssh_agent_unlocking_events", id: :integer, charset: "utf8mb3", collation: "utf8mb3_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.string "message"
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "sync_status", id: :integer, charset: "utf8mb3", collation: "utf8mb3_unicode_ci", force: :cascade do |t|
    t.datetime "accessed_at", precision: nil
    t.datetime "created_at", precision: nil
    t.integer "remote_resource_id"
    t.string "status"
    t.datetime "synced_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "userfile_id"
    t.index ["remote_resource_id"], name: "index_sync_status_on_remote_resource_id"
    t.index ["userfile_id", "remote_resource_id"], name: "index_sync_status_on_userfile_id_and_remote_resource_id", unique: true
    t.index ["userfile_id"], name: "index_sync_status_on_userfile_id"
  end

  create_table "tags", id: :integer, charset: "utf8mb3", collation: "utf8mb3_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.integer "group_id"
    t.string "name"
    t.datetime "updated_at", precision: nil
    t.integer "user_id"
    t.index ["name"], name: "index_tags_on_name"
    t.index ["user_id"], name: "index_tags_on_user_id"
  end

  create_table "tags_userfiles", id: false, charset: "utf8mb3", collation: "utf8mb3_unicode_ci", force: :cascade do |t|
    t.integer "tag_id"
    t.integer "userfile_id"
    t.index ["tag_id"], name: "index_tags_userfiles_on_tag_id"
    t.index ["userfile_id"], name: "index_tags_userfiles_on_userfile_id"
  end

  create_table "tool_configs", id: :integer, charset: "utf8mb3", collation: "utf8mb3_unicode_ci", force: :cascade do |t|
    t.integer "bourreau_id"
    t.string "boutiques_descriptor_path"
    t.string "container_engine"
    t.string "container_exec_args"
    t.integer "container_image_userfile_id"
    t.string "container_index_location"
    t.string "containerhub_image_name"
    t.datetime "created_at", precision: nil
    t.text "description"
    t.text "env_array"
    t.string "extra_qsub_args"
    t.integer "group_id"
    t.boolean "inputs_readonly", default: false
    t.integer "ncpus"
    t.text "script_epilogue"
    t.text "script_prologue"
    t.text "singularity_overlays_specs"
    t.boolean "singularity_use_short_workdir", default: false, null: false
    t.integer "tool_id"
    t.datetime "updated_at", precision: nil
    t.string "version_name"
    t.index ["bourreau_id"], name: "index_tool_configs_on_bourreau_id"
    t.index ["tool_id"], name: "index_tool_configs_on_tool_id"
  end

  create_table "tools", id: :integer, charset: "utf8mb3", collation: "utf8mb3_unicode_ci", force: :cascade do |t|
    t.string "application_package_name"
    t.string "application_tags"
    t.string "application_type"
    t.string "category"
    t.string "cbrain_task_class_name"
    t.datetime "created_at", precision: nil
    t.text "description"
    t.string "descriptor_name"
    t.integer "group_id"
    t.string "name"
    t.string "select_menu_text"
    t.datetime "updated_at", precision: nil
    t.string "url"
    t.integer "user_id"
    t.index ["category"], name: "index_tools_on_category"
    t.index ["cbrain_task_class_name"], name: "index_tools_on_cbrain_task_class"
    t.index ["group_id"], name: "index_tools_on_group_id"
    t.index ["user_id"], name: "index_tools_on_user_id"
  end

  create_table "userfiles", id: :integer, charset: "utf8mb3", collation: "utf8mb3_unicode_ci", force: :cascade do |t|
    t.boolean "archived", default: false, null: false
    t.string "browse_path"
    t.datetime "created_at", precision: nil
    t.integer "data_provider_id"
    t.text "description"
    t.integer "group_id"
    t.boolean "group_writable", default: false, null: false
    t.boolean "hidden", default: false, null: false
    t.boolean "immutable", default: false, null: false
    t.string "name"
    t.integer "num_files"
    t.integer "parent_id"
    t.decimal "size", precision: 24
    t.string "type"
    t.datetime "updated_at", precision: nil
    t.integer "user_id"
    t.string "zenodo_deposit_id"
    t.string "zenodo_doi"
    t.index ["archived", "id"], name: "index_userfiles_on_archived_and_id"
    t.index ["data_provider_id", "browse_path"], name: "index_userfiles_on_data_provider_id_and_browse_path"
    t.index ["data_provider_id"], name: "index_userfiles_on_data_provider_id"
    t.index ["group_id"], name: "index_userfiles_on_group_id"
    t.index ["hidden", "id"], name: "index_userfiles_on_hidden_and_id"
    t.index ["hidden"], name: "index_userfiles_on_hidden"
    t.index ["immutable", "id"], name: "index_userfiles_on_immutable_and_id"
    t.index ["name"], name: "index_userfiles_on_name"
    t.index ["type"], name: "index_userfiles_on_type"
    t.index ["user_id"], name: "index_userfiles_on_user_id"
  end

  create_table "users", id: :integer, charset: "utf8mb3", collation: "utf8mb3_unicode_ci", force: :cascade do |t|
    t.boolean "account_locked", default: false, null: false
    t.string "affiliation"
    t.string "city"
    t.string "country"
    t.datetime "created_at", precision: nil
    t.string "crypted_password"
    t.string "email"
    t.string "full_name"
    t.datetime "last_connected_at", precision: nil
    t.string "login"
    t.boolean "password_reset", default: false, null: false
    t.string "position"
    t.string "salt"
    t.integer "site_id"
    t.string "time_zone"
    t.string "type"
    t.datetime "updated_at", precision: nil
    t.string "zenodo_main_token"
    t.string "zenodo_sandbox_token"
    t.index ["login"], name: "index_users_on_login"
    t.index ["type"], name: "index_users_on_type"
  end

  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
end
