
#
# CBRAIN Project
#
# Copyright (C) 2008-2012
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

FactoryBot.define do

  #################
  # User          #
  #################

  factory :user, class: NormalUser do
    sequence(:login)      { |n| "user#{n}" }
    sequence(:full_name)  { |n| "Bob #{n}" }
    sequence(:email)      { |n| "user#{n}@example.com" }
    password              { "1Password!" }
    password_confirmation { "1Password!" }

    after(:build) do |user|
      user.define_singleton_method(:encrypt_password) do
        self.salt             = 'and pepper'
        self.crypted_password = 'of revenants and zombies'
      end
    end

    trait :encrypted_password do
      after(:build) do |user|
        user.define_singleton_method(:encrypt_password) { user.class.instance_method(:encrypt_password).bind(user).call }
      end
    end
  end

  factory :normal_user, parent: :user, class: NormalUser do
    sequence(:login)      { |n| "normal_user_#{n}" }

    factory :normal_user_with_assocs do
      after(:create) do |nu,_|
        create_list(:work_group_with_assocs,      0, users:  [], access_profiles: [])
        create_list(:access_profiles_with_assocs, 0, groups: [], users:           [])
      end
    end
  end

  factory :site_manager, parent: :user, class: SiteManager do
    sequence(:login)      { |n| "site_manager_#{n}" }
    association :site
  end

  factory :admin_user, parent: :user, class: AdminUser do
    sequence(:login)      { |n| "admin_user_#{n}" }
  end



  #################
  # Group         #
  #################

  # Group is an abstract model and cannot be saved in the DB
  factory :group, class: WorkGroup do
    sequence(:name) { |n| "group_#{n}" }
  end

  factory :work_group do
    sequence(:name) { |n| "work_group_#{n}" }

    factory :work_group_with_assocs do
      after(:create) do |wg, _|
        create_list(:normal_user_with_assocs,    0, groups: [], access_profiles: [])
        create_list(:access_profile_with_assocs, 0, groups: [], users:           [])
      end
    end
  end

  factory :system_group do
    sequence(:name) { |n| "system_group_#{n}" }
  end

  factory :everyone_group do
    sequence(:name) { |n| "everyone_group_#{n}" }
  end

  factory :site_group do
    sequence(:name) { |n| "site_group_#{n}" }
    association :site
  end

  factory :user_group do
    sequence(:name) { |n| "user_group_#{n}" }
  end

  factory :invisible_group, parent: :group  do
    sequence(:name) { |n| "invisible_group_#{n}" }
    invisible { true }
  end



  #################
  # DataProvider  #
  #################

  factory :data_provider do
    sequence(:name) { |n| "dataprovider_#{n}" }
    read_only       { true }
    type            { "FlatDirLocalDataProvider" }
    association     :user, factory: :admin_user
    association     :group
  end

  factory :ssh_data_provider, parent: :data_provider, class: FlatDirSshDataProvider do
    sequence(:name) { |n| "ssh_dataprovider_#{n}" }
  end

  factory :vault_smart_data_provider, parent: :data_provider, class: VaultSmartDataProvider do
    sequence(:name) { |n| "vault_smart_dataprovider_#{n}" }
  end

  factory :vault_ssh_data_provider, parent: :data_provider, class: VaultSshDataProvider do
    sequence(:name) { |n| "vault_ssh_dataprovider_#{n}" }
  end

  factory :vault_local_data_provider, parent: :data_provider, class: VaultLocalDataProvider do
    sequence(:name) { |n| "vault_local_dataprovider_#{n}" }
  end

  factory :flat_dir_local_data_provider, parent: :data_provider, class: FlatDirLocalDataProvider do
    sequence(:name) { |n| "local_dataprovider_#{n}" }
  end

  factory :en_cbrain_smart_data_provider, parent: :data_provider, class: EnCbrainSmartDataProvider do
    sequence(:name) { |n| "en_cb_smart_dataprovider_#{n}" }
  end

  factory :en_cbrain_ssh_data_provider, parent: :data_provider, class: EnCbrainSshDataProvider do
    sequence(:name) { |n| "en_cb_ssh_dataprovider_#{n}" }
  end

  factory :en_cbrain_local_data_provider, parent: :data_provider, class: EnCbrainLocalDataProvider do
    sequence(:name) { |n| "en_cb_local_dataprovider_#{n}" }
  end

  factory :incoming_vault_ssh_data_provider, parent: :data_provider, class: IncomingVaultSshDataProvider do
    sequence(:name) { |n| "in_vault_ssh_dataprovider_#{n}" }
  end



  #################
  # Userfile      #
  #################

  Userfile.nil? # force pre-load of all constants under Userfile

  factory :userfile do
    sequence(:name) { |n| "file_#{n}" }
    association     :user, factory: :normal_user
    association     :group
    association     :data_provider, factory: :ssh_data_provider
  end

  factory :text_file, parent: :userfile, class: TextFile do
    sequence(:name) { |n| "text_file_#{n}" }
    association     :data_provider, factory: :ssh_data_provider
  end

  factory :single_file, parent: :userfile, class: SingleFile do
    sequence(:name) { |n| "single_file_#{n}" }
  end

  factory :file_collection, parent: :userfile, class: FileCollection do
    sequence(:name) { |n| "file_collection_#{n}" }
  end



  ###################
  # Remote Resource #
  ###################

  # RemoteResource is an abstract model and cannot be saved in the DB
  factory :remote_resource, class: Bourreau do
    sequence(:name)    { |n| "rr_#{n}" }
    online             { true }
    dp_ignore_patterns { ["x", "y", "z"] }
    association        :user, factory: :normal_user
    association        :group
  end

  factory :brain_portal, parent: :remote_resource, class: BrainPortal do
    sequence(:name) { |n| "bp_#{n}"}
  end

  factory :bourreau, parent: :remote_resource, class: Bourreau do
    sequence(:name) { |n| "bourreau_#{n}"}
    cms_class       { "ScirSge" }
  end



  ###################
  # CustomFilter    #
  ###################

  factory :custom_filter do
    sequence(:name) { |n| "cf_#{n}"}
    association :user, factory: :normal_user
  end

  begin
    factory :userfile_custom_filter, parent: :custom_filter, class: UserfileCustomFilter do
      sequence(:name) { |n| "ucf_#{n}"}
    end
  rescue
    puts "For the Bourreau-side tests, Userfile custom_filter objects are not required"
  end

  begin
    factory :task_custom_filter, parent: :custom_filter, class: TaskCustomFilter do
      sequence(:name) { |n| "tcf_#{n}"}
    end
  rescue
    puts "For the Bourreau-side tests, Task custom_filter objects are not required"
  end

  ###################
  # Task            #
  ###################

  PortalTask.nil? # force pre-load of all constants under CbrainTask

  # CbrainTask is an abstract model and cannot be saved in the DB
  factory :cbrain_task, class: "cbrain_task/diagnostics" do
    status      { "New" }
    association :bourreau
    association :user, factory: :normal_user
    association :group
    association :tool_config
  end

  factory :portal_task, parent: :cbrain_task, class: "cbrain_task/diagnostics" do
  end

  factory :cluster_task, parent: :cbrain_task, class: "cbrain_task/diagnostics" do
  end


  factory "cbrain_task/diagnostics", parent: :cbrain_task, class: "cbrain_task/diagnostics" do
    status      { "New" }
    association :bourreau
    association :user, factory: :normal_user
    association :group
    association :tool_config
  end



  ###################
  # Other           #
  ###################

  factory :tool do
    sequence(:name)        { |n| "tool_#{n}" }
    category               { "scientific tool" }
    cbrain_task_class_name { |n| "CbrainTask::Snoozer#{n}"}
    association            :user, factory: :normal_user
    association            :group
  end

  factory :tool_config do
    description  { "desc1" }
    version_name { "1.1.12" }
    association  :bourreau
    association  :tool
    association  :group
  end

  factory :tag do
    sequence(:name) { |n| "tag_#{n}" }
    association     :user, factory: :normal_user
    association     :group
  end

  factory :site do
    sequence(:name) { |n| "site_#{n}" }
  end

  factory :message do
    association :user, factory: :normal_user
  end

  factory :feedback do
    summary     { "subject" }
    details     { "core" }
    association :user, factory: :normal_user
  end

  factory :cbrain_session do
  end

  factory :access_profile do
    sequence(:name)        { |n| "ap_#{n}" }
    sequence(:description) { |n| "description for ap_#{n}" }

    factory :access_profile_with_assocs do
      after(:create) do |ap, _|
        create_list(:normal_user_with_assocs,  0, groups: [], access_profiles: [] )
        create_list(:work_group_with_assocs,   0, users:  [], access_profiles: [] )
      end
    end
  end

end
