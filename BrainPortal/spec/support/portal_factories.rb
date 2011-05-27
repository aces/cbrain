Factory.define :user do |user|
  user.full_name             "Bob Brainiac"
  user.sequence(:login)      { |n| "user#{n}" }
  user.sequence(:email)      { |n| "user#{n}@example.com" }
  user.password              "password"
  user.password_confirmation "password"
  user.role                  "user"
  user.association           :site
end

Factory.sequence(:group_name)  { |n| "group_#{n}" }

Factory.define :group do |group| 
  group.name { Factory.next :group_name }
end

Factory.define :work_group do |work_group| 
  work_group.name { Factory.next :group_name }
end

Factory.define :system_group do |system_group| 
  system_group.name { Factory.next :group_name }
end

Factory.define :site_group do |site_group| 
  site_group.name { Factory.next :group_name }
end

Factory.define :user_group do |user_group| 
  user_group.name { Factory.next :group_name }
end

Factory.define :invisible_group do |invisible_group| 
  invisible_group.name { Factory.next :group_name }
end

Factory.define :site  do |site|
  site.sequence(:name) { |n| "site_#{n}" }
end

Factory.define :data_provider do |data_provider|
  data_provider.sequence(:name) { |n| "dataprovider_#{n}" }
  data_provider.association     :user
  data_provider.association     :group
  data_provider.read_only       true
  data_provider.class           {"CbrainLocalDataProvider"}
end

Factory.define :tool do |tool|
  tool.sequence(:name) { |n| "tool_#{n}" }
  tool.association     :user
  tool.association     :group
  tool.category        "scientific tool"
end

Factory.define :userfile do |userfile|
    userfile.sequence(:name) { |n| "file_#{n}" }
    userfile.association     :user
    userfile.association     :group
    userfile.association     :data_provider
end

Factory.define :niak_fmri_study do |userfile|
    userfile.sequence(:name) { |n| "file_#{n}" }
    userfile.association     :user
    userfile.association     :group
    userfile.association     :data_provider
end

Factory.define :single_file do |single_file|
    single_file.sequence(:name) { |n| "file_#{n}" }
    single_file.association     :user
    single_file.association     :group
    single_file.association     :data_provider
end

Factory.define :file_collection do |file_collection|
    file_collection.sequence(:name) { |n| "file_#{n}" }
    file_collection.association     :user
    file_collection.association     :group
    file_collection.association     :data_provider
end

Factory.define :tag do |tag|
  tag.sequence(:name) { |n| "tag_#{n}" }
  tag.association     :user
  tag.association     :group
end

Factory.define :remote_resource do |remote_resource|
  remote_resource.sequence(:name) { |n| "rr_#{n}" }
  remote_resource.association     :user
  remote_resource.group           Group.find_by_name('everyone')
  remote_resource.online          true
end

Factory.define :brain_portal do |brain_portal|
  brain_portal.sequence(:name) { |n| "bp_#{n}"}
  brain_portal.association :user
  brain_portal.group  Group.find_by_name('everyone')
  brain_portal.online true 
end

Factory.define :feedback do |feedback|
  feedback.association :user
  feedback.summary     "subject"
  feedback.details     "core"
end

Factory.define :custom_filter do |custom_filter|
  custom_filter.sequence(:name) { |n| "cf_#{n}"}
  custom_filter.association :user
end

Factory.define :userfile_custom_filter do |userfile_custom_filter|
  userfile_custom_filter.sequence(:name) { |n| "ucf_#{n}"}
  userfile_custom_filter.association :user
end

Factory.define :task_custom_filter do |task_custom_filter|
  task_custom_filter.sequence(:name) { |n| "tcf_#{n}"}
  task_custom_filter.association :user
end

Factory.define :bourreau do |bourreau|
  bourreau.sequence(:name) { |n| "bourreau_#{n}"}
  bourreau.association :user
  bourreau.association :group
end

Factory.define :tool_config do |tool_config|
  tool_config.description "desc1"
end

Factory.define :cbrain_task do |cbrain_task|
  cbrain_task.status      "New"
  cbrain_task.association :bourreau
  cbrain_task.association :user
  cbrain_task.association :group
  cbrain_task.association :tool_config
end

Factory.define "cbrain_task/diagnostics" do |cbrain_task|
  cbrain_task.status      "New"
  cbrain_task.type "CbrainTask::Diagnostics"
  cbrain_task.association :bourreau
  cbrain_task.association :user
  cbrain_task.association :group
  cbrain_task.association :tool_config
end

Factory.define "cbrain_task/civet" do |cbrain_task|
  cbrain_task.status      "New"
  cbrain_task.type "CbrainTask::Civet"
  cbrain_task.association :bourreau
  cbrain_task.association :user
  cbrain_task.association :group
  cbrain_task.association :tool_config
end

