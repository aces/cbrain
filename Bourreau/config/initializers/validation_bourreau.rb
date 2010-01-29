
#
# CBRAIN Project
#
# Validation code for Bourreau
#
# Original author: Pierre Rioux
#
# $Id$
#

#-----------------------------------------------------------------------------
puts "C> CBRAIN Bourreau validation starting, " + Time.now.to_s
#-----------------------------------------------------------------------------
require 'socket'



#-----------------------------------------------------------------------------
puts "C> Verifying configuration variables..."
#-----------------------------------------------------------------------------

Needed_Constants = %w(
                       DataProviderCache_dir
                       DRMAA_sharedir Quarantine_dir CIVET_dir
                       BOURREAU_CLUSTER_NAME CLUSTER_TYPE DEFAULT_QUEUE
                       EXTRA_QSUB_ARGS EXTRA_BASH_INIT_CMDS
                       BOURREAU_WORKERS_INSTANCES
                       BOURREAU_WORKERS_CHECK_INTERVAL
                       BOURREAU_WORKERS_LOG_TO
                       BOURREAU_WORKERS_VERBOSE
                     )

# Constants
Needed_Constants.each do |c|
  unless CBRAIN.const_defined?(c)
    raise "Configuration error: the CBRAIN constant '#{c}' is not defined!\n" +
          "Check 'config_bourreau.rb' (and compare it to 'config_bourreau.rb.TEMPLATE')."
  end
end
  
# Run-time checks
unless File.directory?(CBRAIN::DataProviderCache_dir)
  raise "CBRAIN configuration error: data provider cache dir '#{CBRAIN::DataProviderCache_dir}' does not exist!"
end
unless File.directory?(CBRAIN::DRMAA_sharedir)
  raise "CBRAIN configuration error: grid work directory '#{CBRAIN::DRMAA_sharedir}' does not exist!"
end
unless File.directory?(CBRAIN::Quarantine_dir)
  raise "CBRAIN configuration error: quarantine dir '#{CBRAIN::Quarantine_dir}' does not exist!"
end
unless File.directory?(CBRAIN::CIVET_dir)
  raise "CBRAIN configuration error: civet code dir '#{CBRAIN::CIVET_dir}' does not exist!"
end

if CBRAIN::BOURREAU_CLUSTER_NAME.empty? || CBRAIN::BOURREAU_CLUSTER_NAME == "nameit"
  raise "CBRAIN configuration error: this Bourreau has not been given a name!"
else
  bourreau = Bourreau.find_by_name(CBRAIN::BOURREAU_CLUSTER_NAME)
  if bourreau
    CBRAIN::BOURREAU_ID = bourreau.id # this is my own ID, then.
  else
    raise "CBRAIN configuration error: can't find ActiveRecord for a Bourreau with name '#{CBRAIN::BOURREAU_CLUSTER_NAME}'."
  end
end

if ! CBRAIN::EXTRA_BASH_INIT_CMDS.is_a?(Array) || CBRAIN::EXTRA_BASH_INIT_CMDS.find { |s| ! s.is_a?(String) }
  raise "CBRAIN configuration error: the EXTRA_BASH_INIT_CMDS is not an array of strings!"
end

if CBRAIN::BOURREAU_WORKERS_INSTANCES > 1
  raise "Error: right now we only support a SINGLE instance of a Bourreau Worker! Check your value for BOURREAU_WORKERS_INSTANCES."
end



#-----------------------------------------------------------------------------
puts "C> Ensuring that this RAILS app is registered as a RemoteResource..."
#-----------------------------------------------------------------------------

dp_cache_md5     = DataProvider.cache_md5
bourreau_by_md5  = Bourreau.find(:first,
                   :conditions => { :cache_md5 => dp_cache_md5 })
bourreau_by_name = Bourreau.find(:first,
                   :conditions => { :name => CBRAIN::BOURREAU_CLUSTER_NAME })

if bourreau_by_md5 && bourreau_by_name
  if bourreau_by_md5.id != bourreau_by_name.id
    raise "Error! Found two Bourreau records for this rails APP, but they conflict!"
  end
elsif bourreau_by_md5 || bourreau_by_name
  puts "C> \t- Adjusting Bourreau record for this RAILS app."
  bourreau = bourreau_by_md5 || bourreau_by_name # which ever is defined
  bourreau.cache_md5 = dp_cache_md5
  bourreau.name      = CBRAIN::BOURREAU_CLUSTER_NAME
  bourreau.save!
else
  puts "C> \t- Creating a new Bourreau record for this RAILS app."
  admin  = User.find_by_login('admin')
  gadmin = Group.find_by_name('admin')
  bourreau = Bourreau.create!(
                  :name        => CBRAIN::BOURREAU_CLUSTER_NAME,
                  :user_id     => admin.id,
                  :group_id    => gadmin.id,
                  :online      => true,
                  :read_only   => false,
                  :description => 'Bourreau on host ' + Socket.gethostname,
                  :cache_md5   => dp_cache_md5 )
  puts "C> \t- NOTE: You might want to edit it using the Portal's interface."
end

# This constant is helpful whenever we want to
# access the info about this very RAILS app.
# Note that SelfRemoteResourceId is used by SyncStatus methods.
CBRAIN::SelfRemoteResourceId = bourreau.id



#-----------------------------------------------------------------------------
puts "C> Checking to see if Data Provider caches need wiping..."
#-----------------------------------------------------------------------------
dp_init_rev    = DataProvider.cache_revision_of_last_init  # will be "0" if unknown
dp_current_rev = DataProvider.revision_info.svn_id_rev
raise "Serious Internal Error: I cannot get a numeric SVN revision number for DataProvider?!?" unless
   dp_current_rev && dp_current_rev =~ /^\d+/
if dp_init_rev.to_i <= 659 # Before Pierre's upgrade
  puts "C> \t- Data Provider Caches are being wiped (Rev: #{dp_init_rev} vs #{dp_current_rev})..."
  puts "C> \t- WARNING: This could take a long time so you should not"
  puts "C> \t  start another instance of this Rails application."
  Dir.chdir(DataProvider.cache_rootdir) do
    Dir.foreach(".") do |entry|
      next unless File.directory?(entry) && entry !~ /^\./
      puts "C> \t\t- Removing old cache subdirectory '#{entry}' ..."
      FileUtils.remove_entry(entry, true) rescue true
    end
  end
  puts "C> \t- Synchronization objects are being wiped..."
  synclist = SyncStatus.find(:all, :conditions => { :remote_resource_id => CBRAIN::SelfRemoteResourceId })
  synclist.each do |ss|
    ss.destroy rescue true
  end
  puts "C> \t- Re-recording DataProvider revision number in cache."
  DataProvider.cache_revision_of_last_init(:force)
  puts "C> \t- Done."
end



#-----------------------------------------------------------------------------
puts "C> Making sure all providers have proper cache subdirectories..."
#-----------------------------------------------------------------------------

# Creating cache dir for Data Providers
DataProvider.all.each do |p|
  begin
    p.mkdir_cache_providerdir
  rescue => e
    unless e.to_s.match(/No caching in this provider/i)
      raise e
    end
  end
end



#-----------------------------------------------------------------------------
puts "C> Loading cluster management SCIR layers..."
#-----------------------------------------------------------------------------

# Load the proper class for interacting with the cluster
case CBRAIN::CLUSTER_TYPE
  when "SGE"
    require 'scir_sge.rb'
  when "PBS"
    require 'scir_pbs.rb'
  when "UNIX"
    require 'scir_local.rb'
  when "MOAB"
    require 'scir_moab.rb'
  when "SHARCNET"
    require 'scir_sharcnet.rb'
  else
    raise "CBRAIN configuration error: CLUSTER_TYPE is set to unknown value '#{CBRAIN::CLUSTER_TYPE}' !"
end
puts "C> \t - Layer for '#{CBRAIN::CLUSTER_TYPE}' loaded."



#-----------------------------------------------------------------------------
puts "C> Reporting Bourreau Worker Processes (if any)..."
#-----------------------------------------------------------------------------

# This will reconnect with any and all workers already
# running, for instance if Bourreau was shut down and the workers
# were still alive.
allworkers = BourreauWorker.rescan_workers
allworkers.each do |worker|
  puts "C> \t - Found worker already running: #{worker.pid.to_s} ..."
end
if allworkers.size == 0
  puts "C> \t - No worker process found. It's OK, they'll be started as needed."
else
  puts "C> \t - Scheduling restart for all of them ..."
  BourreauWorker.wake_all
  BourreauWorker.signal_all('TERM')
end



#-----------------------------------------------------------------------------
puts "C> Informing outside world that validations have passed..."
#-----------------------------------------------------------------------------

# The CBRAIN_SERVER_STATUS_FILE environment variable is set up in the
# CBRAIN wrapper script 'cbrain_remote_ctl'. If it's not set we do not do
# anything. It's used by the wrapper to figure out if we launched properly.
server_status_file = ENV["CBRAIN_SERVER_STATUS_FILE"]
if ! server_status_file.blank?
  File.open(server_status_file,"w") do |fh|
    fh.write "STARTED\n"
  end
end

