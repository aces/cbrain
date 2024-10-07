
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

#
# Seed for CBRAIN API Tests
#
# Create just the minimal necessary records for running API tests.
#

require 'readline'
require 'socket'
require 'etc'

#
# ActiveRecord extensions for seeding
#
class ApplicationRecord

  def self.seed_record!(attlist, create_attlist = {}, options = { :info_name_method => :name })
    raise "Bad attribute list." if attlist.blank? || ! attlist.is_a?(Hash)

    top_superclass = self
    while top_superclass.superclass < ApplicationRecord
      top_superclass = top_superclass.superclass
    end

    exists = top_superclass.where(attlist).all

    # None exists? Create one.
    if exists.empty?
      new_record = self.new()
      attlist.merge(create_attlist).each do |att,val|
        new_record.send("#{att}=",val)
      end
      yield(new_record) if block_given?
      new_record.save!
      puts "#{new_record.class} ##{new_record.id} '#{new_record.send(options[:info_name_method])}' : created." if options[:info_name_method]
      return new_record
    end

    # One exists? Check it.
    if exists.size == 1
      exist = exists[0]
      raise "Tried to seed a record of class #{self.name} but found one of class #{exist.class.name} !" unless exist.is_a?(self)
      create_attlist.each do |att,val|
        exist.send("#{att}=",val)
      end
      # Check other properties here?
      yield(exist) if block_given?
      exist.save!
      puts "#{exist.class} ##{new_record.id} '#{exist.send(options[:info_name_method])}' : updated." if options[:info_name_method]
      return exist
    end

    # More than one exists? Die.
    raise "Several (#{exists.size}) #{top_superclass.name} objects already exists with these attributes."
  end

end

#------------------------------------------------
# Seeding steps starts here
#------------------------------------------------

trap('INT') { puts "\n\nInterrupt. Exiting."; exit(0) }
hostname = Socket.gethostname

myself = RemoteResource.current_resource
raise "You can only run this seeding process as a BrainPortal CBRAIN application!" unless
  myself.is_a?(BrainPortal)
myrailsenv = Rails.env || "production"
raise "You can only run this seeding process under a 'test' Rails environement!" unless
  myrailsenv =~ /test/

unix_user  = Etc.getpwuid(Process.uid).name rescue ENV['USER']
rails_home = Rails.root.to_s

default_support_dir  = "#{rails_home}/tmp"


print <<INTRO

===========================================================
CBRAIN seeding process for testing the API.

This code will install some records needed in a test
database such that the testing code for the API will work properly.

A standard seeding process of the test database should already
have been run (with "rake db:seed #{myrailsenv}").

You can run it multiple times without fear.
===========================================================
INTRO



puts <<STEP

----------------------------
Step 1: Clean Everything
----------------------------

STEP

AccessProfile.delete_all
LargeSessionInfo.delete_all
ToolConfig.delete_all
Tag.delete_all
SshAgentUnlockingEvent.delete_all
ActiveRecordLog.delete_all
MetaDataStore.delete_all
Tool.delete_all
SyncStatus.delete_all
Userfile.delete_all
CbrainTask.delete_all
Bourreau.delete_all
DataProvider.delete_all
User.all.delete_all
Group.all.delete_all
puts "All done.";



puts <<STEP

----------------------------
Step 2: Admin User Updated
----------------------------

STEP

eg=EveryoneGroup.new(:id => 1, :name => 'everyone')
eg.save!

admin = CoreAdmin.seed_record!(
  { :full_name => "CBRAIN Administrator",
    :login     => "admin",
  },
  {
    :id => 1,
    :email => 'nobody@localhost',
    :password_reset => false,
  },
  { :info_name_method => :login }
) do |u|
  u.password              = u.login + "_123"
  u.password_confirmation = u.login + "_123"
end

# Fix admin's own_group to ID '2'
orig_admin_group=admin.own_group
admin_group=orig_admin_group.dup
orig_admin_group.delete
admin_group.id=2
admin_group.save!
admin_group.user_ids = [ 1 ]
admin = CoreAdmin.first # must reload afresh

puts "Updated UserGroup for admin: #{admin_group.inspect}"



puts <<STEP

----------------------------
Step 3: Normal User Created
----------------------------

STEP

normal = NormalUser.seed_record!(
  { :full_name => "Normal User",
    :login     => "norm",
  },
  {
    :id        => 2,
    :email     => "norm@localhost",
    :site_id   => nil,
    :time_zone => 'UTC',
    :city      => 'London',
    :country   => 'England',
    :account_locked => false,
    :password_reset => false,
    :last_connected_at => nil,
  },
  { :info_name_method => :login }
) do |u|
  u.password              = u.login + "_123"
  u.password_confirmation = u.login + "_123"
end

# Fix Norm's own group to ID '3'
orig_norm_group=normal.own_group
norm_group=orig_norm_group.dup
orig_norm_group.delete
norm_group.id=3
norm_group.save!
norm_group.user_ids = [ 2 ]
normal = NormalUser.first # must reload afresh




puts <<STEP

----------------------------
Step 4: Seed three fake API sessions
----------------------------

STEP

# This session will be use to test the API as an admin user
LargeSessionInfo.seed_record!(
  { session_id: "0123456789abcdef0123456789abcdef", },
  {
    user_id:    admin.id,
    active:     true,
    data:       {  :guessed_remote_ip   => "127.0.0.1",
                   :guessed_remote_host => "api_test_host",
                   :raw_user_agent      => "Rake_API_Test/ruby",
                   :api                 => "yes",
                },
  },
  { :info_name_method => :session_id }
)

# This session will be use to test the API as normal user
LargeSessionInfo.seed_record!(
  { session_id: "0123456789abcdeffedcba9876543210", },
  {
    user_id:    normal.id,
    active:     true,
    data:       {  :guessed_remote_ip   => "127.0.0.1",
                   :guessed_remote_host => "api_test_host",
                   :raw_user_agent      => "Rake_API_Test/ruby",
                   :api                 => "yes",
                },
  },
  { :info_name_method => :session_id }
)

# This session will be only be used to test the DESTROY SESSION
# action.
LargeSessionInfo.seed_record!(
  { session_id: "0123456789abcdefffffffffffffffff", },
  {
    user_id:    normal.id,
    active:     true,
    data:       {  :guessed_remote_ip   => "127.0.0.1",
                   :guessed_remote_host => "api_test_host",
                   :raw_user_agent      => "Rake_API_Test/ruby",
                   :api                 => "yes",
                },
  },
  { :info_name_method => :session_id }
)



puts <<STEP

----------------------------
Step 5: Groups
----------------------------

STEP

g1 = WorkGroup.seed_record!(
  { :name       => 'NormTest1' },
  { :id         => 10,
    :creator_id => normal.id,
    :invisible  => false,
  }
)
g1.user_ids = [ normal.id ]

g2 = WorkGroup.seed_record!(
  { :name       => 'NormDel' },
  { :id         => 11,
    :creator_id => normal.id,
    :invisible  => false,
  }
)
g2.user_ids = [ normal.id ]

EveryoneGroup.first.user_ids = [] # zap
EveryoneGroup.first.user_ids = [ admin.id, normal.id ]



puts <<STEP

----------------------------
Step 6: Portal And Bourreau
----------------------------

STEP

# Adjust attributes to the Portal object
system("rm -rf   '#{default_support_dir}/test_api/portal/cache'") if
  File.directory?("#{default_support_dir}/test_api/portal/cache")
system("mkdir -p '#{default_support_dir}/test_api/portal/cache'")

po=BrainPortal.first.dup
po.id          = CBRAIN::SelfRemoteResourceId = 1 # reassign just to be sure
po.description = 'Test Portal'
po.user_id     = admin.id
po.group_id    = EveryoneGroup.first.id
po.dp_cache_dir = "#{default_support_dir}/test_api/portal/cache"
po.cache_md5    = '000aaabbbc06331af4fa51d2862a96ec' # arbitrary
BrainPortal.first.delete
po.save!

%w( test_api test_api/bourreau test_api/bourreau/cache test_api/bourreau/gridshare ).each do |path|
  Dir.mkdir("#{default_support_dir}/#{path}") unless Dir.exists?("#{default_support_dir}/#{path}")
end

bo = Bourreau.seed_record!(
  { :name                  => 'TestExec' },
  { :id                    => 13,
    :user_id               => admin.id,
    :group_id              => EveryoneGroup.first.id,
    :online                => true,
    :read_only             => false,
    :description           => "Test Exec",
    :ssh_control_user      => unix_user,
    :ssh_control_host      => hostname,
    :ssh_control_rails_dir => (Pathname.new(rails_home).parent + "Bourreau").to_s,
    :cache_md5             => '1d1b0f2d6c06331af4fa51d2862a96ec', # arbitrary
    :dp_cache_dir          => "#{default_support_dir}/test_api/bourreau/cache",
    :cms_shared_dir        => "#{default_support_dir}/test_api/bourreau/gridshare",
  }
)

b1 = Bourreau.seed_record!(
    { :name                  => 'OfflineTestExec' },
    { :id                    => 14,
      :user_id               => admin.id,
      :group_id              => EveryoneGroup.first.id,
      :online                => false,
      :read_only             => false,
      :description           => "Test Exec",
      :ssh_control_user      => unix_user,
      :ssh_control_host      => hostname,
      :ssh_control_rails_dir => (Pathname.new(rails_home).parent + "Bourreau").to_s,
      :cache_md5             => '1d1b0f2d6c06331af4fa51d2862a96ec', # arbitrary
      :dp_cache_dir          => "#{default_support_dir}/test_api/bourreau/cacheoff",
      :cms_shared_dir        => "#{default_support_dir}/test_api/bourreau/gridshareoff",
    }
)



puts <<STEP

----------------------------
Step 7: DataProvider
----------------------------

STEP

%w( test_api test_api/localdp test_api/carmindp ).each do |path|
  Dir.mkdir("#{default_support_dir}/#{path}") unless Dir.exists?("#{default_support_dir}/#{path}")
end

dp = FlatDirLocalDataProvider.seed_record!(
  { :name         => 'TestDP' },
  { :id           => 15,
    :user_id      => admin.id,
    :group_id     => EveryoneGroup.first.id,
    :online       => true,
    :remote_dir   => "#{default_support_dir}/test_api/localdp",
    :read_only    => false,
    :description  => 'Test DP',
    :not_syncable => false,
  }
)

system("rm -rf '#{default_support_dir}/test_api/localdp/'*")
system("touch '#{default_support_dir}/test_api/localdp/new1.txt' '#{default_support_dir}/test_api/localdp/new2.log'")
system("touch '#{default_support_dir}/test_api/localdp/del1'     '#{default_support_dir}/test_api/localdp/del2'")

carmindp = CarminPathDataProvider.seed_record!(
  { :name         => 'CarminDP' },
  { :id           => 16,
    :user_id      => admin.id,
    :group_id     => EveryoneGroup.first.id,
    :online       => true,
    :remote_dir   => "#{default_support_dir}/test_api/carmindp",
    :read_only    => false,
    :description  => 'Carmin DP',
    :not_syncable => false,
    # These two are necessary so that it acts as a local provider, and won't even try to ssh
    :remote_host  => Socket.gethostname,
    :remote_user  => Etc.getpwuid(Process.uid).name,
  }
)

system("rm -rf        '#{default_support_dir}/test_api/carmindp/'*")
system("mkdir -p      '#{default_support_dir}/test_api/carmindp/norm/topdir/subdir'")
system("echo hello1 > '#{default_support_dir}/test_api/carmindp/norm/topdir/file1.txt'")
system("echo hello2 > '#{default_support_dir}/test_api/carmindp/norm/topdir/subdir/file2.txt'")
system("echo superb > '#{default_support_dir}/test_api/carmindp/norm/topfile.txt'")



puts <<STEP

----------------------------
Step 8: Tool
----------------------------

STEP

to = Tool.seed_record!(
  { :name => 'SimpleMonitor' },
  { :id   => 17,
    :user_id      => admin.id,
    :group_id     => EveryoneGroup.first.id,
    :category     => 'scientific tool',
    :cbrain_task_class_name => 'CbrainTask::SimpleMonitor',
    :select_menu_text => 'Mon',
    :description  => 'TestMon',
    :url          => 'http://localhost',
  }
)



puts <<STEP

----------------------------
Step 9: ToolConfigs
----------------------------

STEP

tca = ToolConfig.seed_record!(
  { :version_name => 'admin1' },
  { :id           => 19,
    :group_id     => admin.own_group.id,
    :description  => 'admin_only',
    :tool_id      => to.id,
    :bourreau_id  => b1.id,
    :ncpus        => 99,
    :env_array    => [],
  }
)

tcn = ToolConfig.seed_record!(
  { :version_name => 'norm1' },
  { :id           => 20,
    :group_id     => EveryoneGroup.first.id,
    :description  => 'all_users',
    :tool_id      => to.id,
    :bourreau_id  => bo.id,
    :ncpus        => 99,
    :env_array    => [],
  }
)



puts <<STEP

----------------------------
Step 10: Tags
----------------------------

STEP

Tag.seed_record!(
  { :name => 'tag1' },
  { :id   => 21,
    :user_id => normal.id,
    :group_id => normal.own_group.id,
  }
)

Tag.seed_record!(
  { :name => 'tagdel' },
  { :id   => 99,
    :user_id => normal.id,
    :group_id => normal.own_group.id,
  }
)



puts <<STEP

----------------------------
Step 10: Userfiles
----------------------------

STEP

f1 = TextFile.seed_record!(
  { :name => 'admin.txt' },
  { :id   => 1,
    :user_id => admin.id,
    :group_id => admin.own_group.id,
    :data_provider_id => dp.id,
    :num_files => 1,
    :group_writable => false,
    :hidden => false,
    :immutable => false,
    :archived => false,
    :description => 'test file1',
  }
)
f1.cache_writehandle { |fh| fh.write "admin content" }
f1.set_size

f2 = TextFile.seed_record!(
  { :name => 'norm.json' },
  { :id   => 2,
    :user_id => normal.id,
    :group_id => normal.own_group.id,
    :data_provider_id => dp.id,
    :num_files => 1,
    :group_writable => false,
    :hidden => false,
    :immutable => false,
    :archived => false,
    :description => 'test file2',
  }
)
f2.cache_writehandle { |fh| fh.write '{"fake":"normal content"}' }
f2.set_size

f3 = TextFile.seed_record!(
  { :name => 'tounreg1.txt' },
  { :id   => 3,
    :user_id => normal.id,
    :group_id => normal.own_group.id,
    :data_provider_id => dp.id,
    :num_files => 1,
    :group_writable => false,
    :hidden => false,
    :immutable => false,
    :archived => false,
    :description => 'to unregister',
  }
)
f3.cache_writehandle { |fh| fh.write "unreg content" }
f3.set_size

f4 = TextFile.seed_record!(
  { :name => 'todel.txt' },
  { :id   => 4,
    :user_id => normal.id,
    :group_id => normal.own_group.id,
    :data_provider_id => dp.id,
    :num_files => 1,
    :group_writable => false,
    :hidden => false,
    :immutable => false,
    :archived => false,
    :description => 'to unregister',
  }
)
f4.cache_writehandle { |fh| fh.write "del content" }
f4.set_size

f5=f4.dup
f5.name = "todelmult.txt";
f5.id   = 5
f5.save! # we don't care for actual content for this one

f6 = DatFile.seed_record!(
  { :name => 'binary.dat' },
  { :id   => 6,
    :user_id => normal.id,
    :group_id => normal.own_group.id,
    :data_provider_id => dp.id,
    :num_files => 1,
    :group_writable => false,
    :hidden => false,
    :immutable => false,
    :archived => false,
    :description => 'binary data',
  }
)
f6.cache_writehandle { |fh| fh.binmode;fh.write "\xff" }
f6.set_size

SyncStatus.delete_all # clean all sync info again

carmindir = FileCollection.seed_record!(
  { :name => 'topdir' },
  { :id   => 10,
    :size => 0,
    :user_id => normal.id,
    :group_id => normal.own_group.id,
    :data_provider_id => carmindp.id,
    :num_files => 2,
    :group_writable => false,
    :hidden => false,
    :immutable => false,
    :archived => false,
    :description => 'carmin existing',
  }
)
carminfile = TextFile.seed_record!(
  { :name => 'topfile.txt' },
  { :id   => 11,
    :size => 7,
    :user_id => normal.id,
    :group_id => normal.own_group.id,
    :data_provider_id => carmindp.id,
    :num_files => 2,
    :group_writable => false,
    :hidden => false,
    :immutable => false,
    :archived => false,
    :description => 'superb',
  }
)



puts <<STEP

----------------------------
Step 11: CbrainTask
----------------------------

STEP

CbrainTask.nil? # must preload for some reason
PortalTask.nil? # must preload for some reason
t2 = CbrainTask::SimpleMonitor.seed_record!(
  { :id => 2 },
  { :params => { },
    :status => "Completed",
    :user_id => 2,
    :group_id => normal.own_group.id,
    :bourreau_id => bo.id,
    :description => "ExistTest",
    :run_number => 1,
    :tool_config_id => tcn.id,
    :level => nil,
    :rank => nil,
    :results_data_provider_id => 15,
    :cluster_workdir_size => 123456,
    :workdir_archived => false,
    :workdir_archive_userfile_id => 9876,
  }
)

t3=t2.dup
t3.id = 3
t3.description = 'DelTest'
t3.save!

t4=t2.dup
t4.id = 4
t4.description = 'CarminDelTest'
t4.save!

# Delete test
t5=t2.dup
t5.id = 5
t5.description = 'DelTestWithoutWorkdir'
t5.save!

# This one has a fake workdir, so deleting requires creating a BAC
t6=t2.dup
t6.id = 6
t6.description = 'DelTestWithWorkdir'
t6.cluster_workdir = "00/00/05/fake"
t6.save!

# Some cleanup
BackgroundActivity.finished.delete_all
BackgroundActivity.where("updated_at < ?",6.minutes.ago).delete_all
