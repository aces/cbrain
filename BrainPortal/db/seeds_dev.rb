
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
# Seed for CBRAIN developers
#
# Create lots and lots of records:
#
# * Sample Sites
# * Sample Users
# * Sample Projects
# * Sample DataProviders
# * Sample Bourreaux
# * Sample Tools
# * Sample ToolConfigs
# * Sample Userfiles
# * Sample Tags
# * Sample Tasks
#
# All of this is meant to provide a developer with a rich environment
# for testing user interface elements, resource access, etc etc.
#

require 'readline'
require 'socket'
require 'etc'

#
# ActiveRecord extensions for seeding
#
class ActiveRecord::Base

  def self.seed_record!(attlist, create_attlist = {}, options = { :info_name_method => :name })
    raise "Bad attribute list." if attlist.blank? || ! attlist.is_a?(Hash)

    top_superclass = self
    while top_superclass.superclass < ActiveRecord::Base
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
      puts "#{new_record.class} '#{new_record.send(options[:info_name_method])}' : created." if options[:info_name_method]
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
      puts "#{exist.class} '#{exist.send(options[:info_name_method])}' : updated." if options[:info_name_method]
      return exist
    end

    # More than one exists? Die.
    raise "Several (#{exists.size}) #{top_superclass.name} objects already exists with these attributes."
  end

end

#------------------------------------------------
# Seeding steps starts here
#------------------------------------------------

raise "The seeding process must be run by a process connected to a terminal" unless
  STDIN.tty? && STDOUT.tty? && STDERR.tty?
stty_save = `stty -g`.chomp
trap('INT') { system('stty', stty_save) ; puts "\n\nInterrupt. Exiting."; exit(0) }
hostname = Socket.gethostname

myself = RemoteResource.current_resource
raise "You can only run this seeding process as a BrainPortal CBRAIN application!" unless
  myself.is_a?(BrainPortal)

unix_user  = Etc.getpwuid(Process.uid).name rescue ENV['USER']
rails_home = Rails.root.to_s
seeds_dev_support_dir = "#{rails_home}/seeds_dev_support_dir"
Dir.mkdir(seeds_dev_support_dir) unless Dir.exists?(seeds_dev_support_dir)

print <<INTRO

===========================================================
CBRAIN seeding process for developers.

This code will install lots of records in the DB to
create a system with enough data to actually help
develop it.

 * Sample Sites
 * Sample Users
 * Sample Projects
 * Sample DataProviders
 * Sample Bourreaux
 * Sample Tools
 * Sample ToolConfigs
 * Sample Userfiles
 * Sample Tags
 * Sample Tasks

You can run it multiple times without fear.

All data files (Data Providers, cache directories, bourreau
work directories etc) will be created in:

  #{seeds_dev_support_dir}

IMPORTANT: Do not run this on a network-accessible
RAILS server or a production server, as it will introduce
several dummy users with weak passwords.
===========================================================
INTRO



puts <<STEP

----------------------------
Step 1: Sites
----------------------------

STEP

long_site = Site.seed_record!(
 { :name => 'Longbourne' },
 { :description => "Hertfordshire\n\nA nice little place in the countryside" }
)
nether_site = Site.seed_record!(
 { :name => 'Netherfield Park' },
 { :description => "Hertfordshire\n\nA larger place in the countryside" }
)
pember_site = Site.seed_record!(
 { :name => 'Pemberley' },
 { :description => "Devonshire\n\nA great place in the countryside" }
)



puts <<STEP

----------------------------
Step 2: Users
----------------------------

STEP

[ "Mr", "Jane", "Elizabeth", "Catherine", "Mary", "Lydia" ].each do |first|
  login = first == "Mr" ? "mrbennet" : "#{first[0].downcase}bennet"
  User.seed_record!(
    { :full_name => "#{first} Bennet",
      :login     => login
    },
    {
      :email     => "#{login}@localhost",
      :type      => (first == "Mr" ? "SiteManager" : "NormalUser"),
      :site_id   => long_site.id,
      :time_zone => 'UTC',
      :city      => 'Meryton',
      :country   => 'England',
      :account_locked => (first == "Lydia")
    },
    { :info_name_method => :login }
  ) do |u|
    u.password              = u.login + "_123"
    u.password_confirmation = u.login + "_123"
  end
end

[ "Charles Bingley", "Caroline Bingley" ].each do |full|
  names=full.split(/ /)
  first = names[0]
  last  = names[1]
  login = "#{first[0,2].downcase}#{last.downcase}"
  User.seed_record!(
    { :full_name => full,
      :login     => login,
    },
    {
      :email     => "#{login}@localhost",
      :type      => (full == "Charles Bingley" ? "SiteManager" : "NormalUser"),
      :site_id   => nether_site.id,
      :time_zone => 'UTC',
      :city      => 'Meryton',
      :country   => 'England',
      :account_locked => false
    },
    { :info_name_method => :login }
  ) do |u|
    u.password              = u.login + "_123"
    u.password_confirmation = u.login + "_123"
  end
end

[ "Mr Darcy", "Georgiana Darcy", "George Wickham" ].each do |full|
  names=full.split(/ /)
  first = names[0]
  last  = names[1]
  login = "#{first[0,2].downcase}#{last.downcase}"
  User.seed_record!(
    { :full_name => full,
      :login     => login,
    },
    {
      :email     => "#{login}@localhost",
      :type      => (full == "Mr Darcy" ? "SiteManager" : "NormalUser"),
      :site_id   => pember_site.id,
      :time_zone => 'UTC',
      :city      => 'Pemberley',
      :country   => 'England',
      :account_locked => (full == "George Wickham")
    },
    { :info_name_method => :login }
  ) do |u|
    u.password              = u.login + "_123"
    u.password_confirmation = u.login + "_123"
  end
end

[ "Charlotte Lucas", "William Collins", "Mr Gardiner" ].each do |full|
  names=full.split(/ /)
  first = names[0]
  last  = names[1]
  login = "#{first[0,2].downcase}#{last.downcase}"
  User.seed_record!(
    { :full_name => full,
      :login     => login,
    },
    {
      :email     => "#{login}@localhost",
      :type      => "NormalUser",
      :site_id   => nil,
      :time_zone => 'UTC',
      :city      => nil,
      :country   => 'England',
      :account_locked => false
    },
    { :info_name_method => :login }
  ) do |u|
    u.password              = u.login + "_123"
    u.password_confirmation = u.login + "_123"
  end
end



puts <<STEP

----------------------------
Step 3: Projects
----------------------------

STEP

wisegroup           = WorkGroup.seed_record!({ :name => 'wise people' })
wisegroup.user_ids  = User.where( :login => [ 'ebennet', 'jbennet', 'mrdarcy', 'gedarcy', 'chbingley', 'mrgardiner' ] ).map(&:id)
wisegroup.save!

dancers             = WorkGroup.seed_record!({ :name => 'dancers' })
dancers.user_ids    = User.where( :login => [ 'mbennet', 'lbennet', 'cbennet' ]).map(&:id)
dancers.save!

gentlemen           = WorkGroup.seed_record!({ :name => 'gentlemen', :invisible => true })
gentlemen.user_ids  = User.where( :login => [ 'mrbennet', 'mrdarcy', 'chbingley', 'mrgardiner' ] ).map(&:id)
gentlemen.save!

ladies              = WorkGroup.seed_record!({ :name => 'ladies', :invisible => true })
ladies.user_ids     = User.where( :login => [ 'jbennet', 'ebennet', 'cabingley', 'gedarcy', 'chlucas' ] ).map(&:id)
ladies.save!

# lydia_hats
WorkGroup.seed_record!({ :name => 'myhats'  }) { |g| g.user_ids = [ User.find_by_login('lbennet').id ] }
# mary_sheets
WorkGroup.seed_record!({ :name => 'mymusic' }) { |g| g.user_ids = [ User.find_by_login('mbennet').id ] }



puts <<STEP

----------------------------
Step 4: Data Providers
----------------------------

STEP

#---------------------------------------------------
cache_ok = DataProvider.this_is_a_proper_cache_dir!(myself.dp_cache_dir, :for_remote_resource_id => myself.id) rescue nil
if !cache_ok
  cache_dir = "#{seeds_dev_support_dir}/portal_data_provider_cache"
  puts <<-WARN
It seems the current CBRAIN application doesn't have a proper
data provider cache directory configured. Creating one in:

  #{cache_dir}

WARN
  myself.dp_cache_dir = cache_dir
  Dir.mkdir(cache_dir) unless Dir.exists?(cache_dir)
  myself.save!
  DataProvider.cache_revision_of_last_init # finalize initialization of dir
end

#---------------------------------------------------
en_dp_dir = "#{seeds_dev_support_dir}/dp_official"
# en_dp
EnCbrainSmartDataProvider.seed_record!({
    :remote_dir => en_dp_dir
  },
  {
    :name => "Official_For_All", :description => 'Official Storage For Everyone',
    :user_id => User.admin.id, :group_id => Group.everyone.id,
    :remote_user => unix_user, :remote_host => hostname,
    :online => true, :read_only => false,
    :not_syncable => false
  })
Dir.mkdir(en_dp_dir) unless Dir.exists?(en_dp_dir)

#---------------------------------------------------
ssh_dp_dir = "#{seeds_dev_support_dir}/dp_browsable"
# ssh_dp
SshDataProvider.seed_record!({
    :remote_dir => ssh_dp_dir
  },
  {
    :name => "Browsable_For_All", :description => 'Browsable For Everyone',
    :user_id => User.admin.id, :group_id => Group.everyone.id,
    :remote_user => unix_user, :remote_host => hostname,
    :online => true, :read_only => false,
    :not_syncable => false
  })
Dir.mkdir(ssh_dp_dir) unless Dir.exists?(ssh_dp_dir)

#---------------------------------------------------
lb_dp_dir = "#{seeds_dev_support_dir}/dp_lb_browsable"
# lb_dp
SshDataProvider.seed_record!({
    :remote_dir => lb_dp_dir
  },
  {
    :name => "Private_Longbourne", :description => 'Browsable Longbourne Private Storage',
    :user_id => User.find_by_login('mrbennet').id, :group_id => long_site.own_group.id,
    :remote_user => unix_user, :remote_host => hostname,
    :online => true, :read_only => false,
    :not_syncable => false
  })
Dir.mkdir(lb_dp_dir) unless Dir.exists?(lb_dp_dir)

#---------------------------------------------------
nether_dp_dir = "#{seeds_dev_support_dir}/dp_nether_official"
# nether_dp
EnCbrainSmartDataProvider.seed_record!({
    :remote_dir => nether_dp_dir
  },
  {
    :name => "Private_Netherfield", :description => 'Netherfield Private Storage',
    :user_id => User.find_by_login('chbingley').id, :group_id => nether_site.own_group.id,
    :remote_user => unix_user, :remote_host => hostname,
    :online => true, :read_only => false,
    :not_syncable => false
  })
Dir.mkdir(nether_dp_dir) unless Dir.exists?(nether_dp_dir)

#---------------------------------------------------
pember_dp_dir = "#{seeds_dev_support_dir}/dp_pember_official"
# pember_dp
EnCbrainSmartDataProvider.seed_record!({
    :remote_dir => pember_dp_dir
  },
  {
    :name => "Private_Pemberley", :description => 'Pemberley Private Storage',
    :user_id => User.find_by_login('mrdarcy').id, :group_id => pember_site.own_group.id,
    :remote_user => unix_user, :remote_host => hostname,
    :online => true, :read_only => false,
    :not_syncable => false
  })
Dir.mkdir(pember_dp_dir) unless Dir.exists?(pember_dp_dir)

#---------------------------------------------------
collins_dp_dir = "#{seeds_dev_support_dir}/dp_collins_browsable"
# collins_dp
SshDataProvider.seed_record!({
    :remote_dir => collins_dp_dir
  },
  {
    :name => "Private_Collins", :description => "Private Storage Of Mr Collins\n\nKeep Out, or I'll tell Lady Catherine DeBourgh!",
    :user_id => User.find_by_login('wicollins').id, :group_id => User.find_by_login('wicollins').own_group.id,
    :remote_user => unix_user, :remote_host => hostname,
    :online => true, :read_only => false,
    :not_syncable => false
  })
Dir.mkdir(collins_dp_dir) unless Dir.exists?(collins_dp_dir)



puts <<STEP

----------------------------
Step 5: Bourreaux
----------------------------

STEP

# This symlink is needed to make the relative symlinks deep INSIDE the Bourreaux work.
File.symlink(
  "#{rails_home}",
  "#{seeds_dev_support_dir}/BrainPortal"
) unless File.symlink?("#{seeds_dev_support_dir}/BrainPortal")

# This symlink is needed to allow the dev bourreaux to find the static file of rev numbers.
File.symlink(
  "#{Pathname.new(rails_home).parent + "cbrain_file_revisions.csv"}",
  "#{seeds_dev_support_dir}/cbrain_file_revisions.csv"
) unless File.symlink?("#{seeds_dev_support_dir}/cbrain_file_revisions.csv")

#-------------------------------------------------------------------
main_bourreau_dir       = "#{seeds_dev_support_dir}/exec_main"
main_bourreau_gridshare = "#{main_bourreau_dir}/gridshare"
main_bourreau_dp_cache  = "#{main_bourreau_dir}/dp_cache"

system("rsync","-a","#{rails_home}/../Bourreau/", main_bourreau_dir);
Dir.mkdir(main_bourreau_gridshare) unless Dir.exists?(main_bourreau_gridshare)
Dir.mkdir(main_bourreau_dp_cache)  unless Dir.exists?(main_bourreau_dp_cache)

main_bourreau = Bourreau.seed_record!({
    :ssh_control_rails_dir => main_bourreau_dir,
    :cms_shared_dir        => main_bourreau_gridshare,
    :dp_cache_dir          => main_bourreau_dp_cache
  },
  {
    :name => "Main_Exec", :description => "Execution Server For Everyone",
    :user_id => User.admin.id, :group_id => Group.everyone.id,
    :ssh_control_user => unix_user, :ssh_control_host => hostname,
    :tunnel_mysql_port  => 28732, :tunnel_actres_port => 28733,
    :online => true, :read_only => false,
    :cms_class => 'ScirUnix',
    :workers_instances => 1, :workers_chk_time => 60, :workers_log_to => 'combined', :workers_verbose => 1
  }
)
File.open("#{main_bourreau_dir}/config/initializers/config_bourreau.rb","w") do |fh|
  fh.write <<-INIT
    # Automatically created by the seeds_dev script
    class CBRAIN
      CBRAIN_RAILS_APP_NAME = "#{main_bourreau.name}"
    end
  INIT
end

#-------------------------------------------------------------------
pember_bourreau_dir       = "#{seeds_dev_support_dir}/exec_pember"
pember_bourreau_gridshare = "#{pember_bourreau_dir}/gridshare"
pember_bourreau_dp_cache  = "#{pember_bourreau_dir}/dp_cache"

system("rsync","-a","#{rails_home}/../Bourreau/", pember_bourreau_dir);
Dir.mkdir(pember_bourreau_gridshare) unless Dir.exists?(pember_bourreau_gridshare)
Dir.mkdir(pember_bourreau_dp_cache)  unless Dir.exists?(pember_bourreau_dp_cache)

pember_bourreau = Bourreau.seed_record!({
    :ssh_control_rails_dir => pember_bourreau_dir,
    :cms_shared_dir        => pember_bourreau_gridshare,
    :dp_cache_dir          => pember_bourreau_dp_cache
  },
  {
    :name => "PemberExec", :description => "Exec For Pemberley People",
    :user_id => User.find_by_login('mrdarcy').id, :group_id => pember_site.own_group.id,
    :ssh_control_user => unix_user, :ssh_control_host => hostname,
    :tunnel_mysql_port  => 28734, :tunnel_actres_port => 28735,
    :online => true, :read_only => false,
    :cms_class => 'ScirUnix',
    :workers_instances => 1, :workers_chk_time => 60, :workers_log_to => 'combined', :workers_verbose => 1
  }
)
File.open("#{pember_bourreau_dir}/config/initializers/config_bourreau.rb","w") do |fh|
  fh.write <<-INIT
    # Automatically created by the seeds_dev script
    class CBRAIN
      CBRAIN_RAILS_APP_NAME = "#{pember_bourreau.name}"
    end
  INIT
end

#-------------------------------------------------------------------
longbourne_bourreau_dir       = "#{seeds_dev_support_dir}/exec_longbourne"
longbourne_bourreau_gridshare = "#{longbourne_bourreau_dir}/gridshare"
longbourne_bourreau_dp_cache  = "#{longbourne_bourreau_dir}/dp_cache"

system("rsync","-a","#{rails_home}/../Bourreau/", longbourne_bourreau_dir);
Dir.mkdir(longbourne_bourreau_gridshare) unless Dir.exists?(longbourne_bourreau_gridshare)
Dir.mkdir(longbourne_bourreau_dp_cache)  unless Dir.exists?(longbourne_bourreau_dp_cache)

longbourne_bourreau = Bourreau.seed_record!({
    :ssh_control_rails_dir => longbourne_bourreau_dir,
    :cms_shared_dir        => longbourne_bourreau_gridshare,
    :dp_cache_dir          => longbourne_bourreau_dp_cache
  },
  {
    :name => "LongbournExec", :description => "Exec For Longbourne People",
    :user_id => User.find_by_login('mrbennet').id, :group_id => long_site.own_group.id,
    :ssh_control_user => unix_user, :ssh_control_host => hostname,
    :tunnel_mysql_port  => 28736, :tunnel_actres_port => 28737,
    :online => true, :read_only => false,
    :cms_class => 'ScirUnix',
    :workers_instances => 1, :workers_chk_time => 60, :workers_log_to => 'combined', :workers_verbose => 1
  }
)
File.open("#{longbourne_bourreau_dir}/config/initializers/config_bourreau.rb","w") do |fh|
  fh.write <<-INIT
    # Automatically created by the seeds_dev script
    class CBRAIN
      CBRAIN_RAILS_APP_NAME = "#{longbourne_bourreau.name}"
    end
  INIT
end



puts <<STEP

----------------------------
Step 6: Tools
----------------------------

STEP

diag_tool = Tool.seed_record!(
  {
    :cbrain_task_class => 'CbrainTask::Diagnostics'
  },
  {
    :name => 'Diagnostics',
    :user_id => User.admin.id, :group_id => Group.everyone.id,
    :category => 'scientific tool',
    :select_menu_text => 'Launch Cluster Diagnostics',
    :description => "Cluster Diagnostics\n\nAvailable to everyone."
  }
)

para_tool = Tool.seed_record!(
  {
    :cbrain_task_class => 'CbrainTask::Parallelizer'
  },
  {
    :name => 'Parallelizer',
    :user_id => User.admin.id, :group_id => Group.everyone.id,
    :category => 'background',
    :select_menu_text => 'N/A : Launch Parallelizer',
    :description => "Standard CBRAIN Task Parallelizer"
  }
)

seri_tool = Tool.seed_record!(
  {
    :cbrain_task_class => 'CbrainTask::CbSerializer'
  },
  {
    :name => 'Serializer',
    :user_id => User.admin.id, :group_id => Group.everyone.id,
    :category => 'background',
    :select_menu_text => 'N/A : Launch Serializer',
    :description => "Standard CBRAIN Task Serializer"
  }
)

sleeper_tool = Tool.seed_record!(
  {
    :cbrain_task_class => 'CbrainTask::Sleeper'
  },
  {
    :name => 'Sleeper',
    :user_id => User.find_by_login('mrbennet').id, :group_id => long_site.own_group.id,
    :category => 'scientific tool',
    :select_menu_text => 'Launch Sleeper',
    :description => "Longbourne people only"
  }
)

snoozer_tool = Tool.seed_record!(
  {
    :cbrain_task_class => 'CbrainTask::Snoozer'
  },
  {
    :name => 'Snoozer',
    :user_id => User.admin.id, :group_id => gentlemen.id,
    :category => 'conversion tool',
    :select_menu_text => 'Launch Snoozer',
    :description => "Only for gentlemen"
  }
)



puts <<STEP

----------------------------
Step 7: ToolConfigs
----------------------------

STEP

version_name = 10

# tc_main
ToolConfig.seed_record!(
  {
    :tool_id     => nil,
    :bourreau_id => main_bourreau.id
  },
  {
    :group_id    => Group.everyone.id,
    :description => 'All Tools On Main',
    :env_array   => [ [ "MAIN_TOOL_CONFIG", "Main-tc-ok" ] ],
    :script_prologue => "\n# Prologue for tool config\necho $MAIN_TOOL_CONFIG\n",
    :ncpus       => 1,
    :version_name     => "#{version_name += 1}"
  },
  { :info_name_method => :description }
)

# tc_diag
ToolConfig.seed_record!(
  {
    :tool_id     => diag_tool.id,
    :bourreau_id => nil
  },
  {
    :group_id    => Group.everyone.id,
    :description => 'Diag On All Bourreaux',
    :env_array   => [ [ "DIAG_TOOL_CONFIG", "Diag-tc-ok" ] ],
    :script_prologue => "\n# Prologue for tool config\necho $DIAG_TOOL_CONFIG\n",
    :ncpus       => 1,
    :version_name     => "#{version_name += 1}"
  },
  { :info_name_method => :description }
)

Bourreau.all.each do |bourreau|

# para_diag
ToolConfig.seed_record!(
  {
    :tool_id     => para_tool.id,
    :description => 'Latest CBRAIN Parallelizer',
    :bourreau_id => bourreau.id
  },
  {
    :group_id    => Group.everyone.id,
    :env_array   => [ ],
    :script_prologue => "",
    :ncpus       => 1,
    :version_name     => "#{version_name += 1}"
  },
  { :info_name_method => :description }
)

# seri_diag
ToolConfig.seed_record!(
  {
    :tool_id     => seri_tool.id,
    :description => 'Latest CBRAIN Serializer',
    :bourreau_id => bourreau.id
  },
  {
    :group_id    => Group.everyone.id,
    :env_array   => [ ],
    :script_prologue => "",
    :ncpus       => 1,
    :version_name     => "#{version_name += 1}"
  },
  { :info_name_method => :description }
)

end # each bourreau

diag_all_tcs = []
[ main_bourreau, pember_bourreau, longbourne_bourreau ].each do |bourreau|
  [ 1, 2, 3].each do |version|
    diag_all_tcs << ToolConfig.seed_record!(
      {
        :description => "Local version with #{version} CPUs",
        :tool_id     => diag_tool.id,
        :bourreau_id => bourreau.id
      },
      {
        :group_id    => Group.everyone.id,
        :env_array   => [ [ "DIAG_ON_BOURREAU_TOOL_CONFIG", "Version-#{version}" ] ],
        :script_prologue => "\n# Prologue for tool config\necho $DIAG_ON_BOURREAU_TOOL_CONFIG\n",
        :ncpus       => version,
        :version_name     => "#{version_name += 1}"
      },
      { :info_name_method => :description }
    )
  end
end

[ main_bourreau, pember_bourreau, longbourne_bourreau ].each do |bourreau|
  [ sleeper_tool, snoozer_tool ].each do |tool|
    [ wisegroup, gentlemen, ladies ].each do |group|
      ToolConfig.seed_record!(
        {
          :tool_id     => tool.id,
          :bourreau_id => bourreau.id,
          :group_id    => group.id
        },
        {
          :description => "For #{group.name} only",
          :env_array   => [ [ "USER_LIST", "#{group.users.map(&:login).join(",")}" ] ],
          :script_prologue => "\n# Prologue for tool config\necho USER_LIST=$USER_LIST\n",
          :ncpus       => 1,
          :version_name     => "#{version_name += 1}"
        },
        { :info_name_method => :description }
      )
    end
  end
end



puts <<STEP

----------------------------
Step 8: Userfiles
----------------------------

STEP

def seeds_dev_tmp_file(content)
  fn = "/tmp/f.#{Process.pid}.#{rand(1000000)}"
  File.open(fn, "w") { |fh| fh.write content }
  if block_given?
    yield fn
    File.unlink(fn)
  else
    fn
  end
end

User.all.each do |user|
  tf = TextFile.seed_record!(
    {
      :name => "diary_for_#{user.login}.txt",
      :user_id => user.id,
      :group_id => user.own_group.id,
      :data_provider_id => en_dp.id,
      :group_writable => false
    }
  )
  seeds_dev_tmp_file("This is my diary.\n\nMy full name is #{user.full_name}.") do |fn|
    tf.cache_copy_from_local_file(fn) if tf.size.blank?
  end

  DataProvider.all.each do |dp|
    next unless dp.can_be_accessed_by?(user)
    user.groups.each do |group|
      ingroup = LogFile.seed_record!(
        {
        :name => "owner_#{user.login}_group_#{group.name.sub(/\W+/,"_")}.log",
        :user_id => user.id,
        :group_id => group.id,
        :data_provider_id => dp.id,
        :group_writable => false
        }
      )
      seeds_dev_tmp_file("Owned by #{user.login}, in group #{group.name}, on DP #{dp.name}\n") do |fn|
        ingroup.cache_copy_from_local_file(fn) if ingroup.size.blank?
      end
    end # each group
  end # each dp
end # each user



puts <<STEP

----------------------------
Step 9: Tags
----------------------------

STEP

diary_tag = Tag.seed_record!(
  {
    :name => 'LongDiaries',
    :user_id => User.find_by_login('mrbennet').id,
    :group_id => long_site.own_group.id
  }
)
Userfile.all.each do |f|
  next unless f.name =~ /diary/
  next unless long_site.user_ids.include?(f.user_id)
  f.tags ||= []
  f.tags += [diary_tag ]
  f.save
end

User.all.each do |user|
  mydiarytag = Tag.seed_record!(
    {
      :name     => "Dia_#{user.login}",
      :user_id  => user.id,
      :group_id => user.own_group.id
    }
  )
  Userfile.find_all_accessible_by_user(user).all.each do |f|
    next unless f.name =~ /diary/
    f.tags ||= []
    f.tags += [ mydiarytag ]
    f.save
  end
end



puts <<STEP

----------------------------
Step 10: Tasks
----------------------------

STEP

User.all.each do |user|
  groups = [ user.own_group ] + user.groups.where( :type => 'WorkGroup' ).all
  groups.each do |group|
    Bourreau.all.each do |bourreau|
      next unless bourreau.can_be_accessed_by?(user)
      [ diag_tool, sleeper_tool, snoozer_tool ].each do |tool|
        howlong = rand(10) + 5
        tc = ToolConfig.find_by_tool_id_and_bourreau_id(tool.id, bourreau.id)
        next unless tc.can_be_accessed_by?(user)
        taskclass = tool.cbrain_task_class.demodulize
        CbrainTask.const_get(taskclass).seed_record!(
          { :user_id                  => user.id,
            :group_id                 => group.id,
            :status                   => 'Terminated',
            :bourreau_id              => bourreau.id,
            :tool_config_id           => tc.id,
            :results_data_provider_id => en_dp.id
          },
          {
            :launch_time => Time.now,
            :description => (tool == diag_tool ? "Some Diagnostics" : "For #{howlong} seconds"),
            :params => { :howlong                => howlong,
                         :interface_userfile_ids => [ Userfile.find_by_user_id(user.id).id ]
                       }
          }
        )
      end # each tool
    end # each bourreau
  end # each group
end # each user

