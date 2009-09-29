
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



#-----------------------------------------------------------------------------
puts "C> Setting up subprocess locks directory..."
#-----------------------------------------------------------------------------

CBRAIN::DRMAA_SubprocessLocksDir = (Pathname.new(CBRAIN::DRMAA_sharedir) + ".SubprocessLocks").to_s
unless File.directory?(CBRAIN::DRMAA_SubprocessLocksDir)
  Dir.mkdir(CBRAIN::DRMAA_SubprocessLocksDir)
  puts " -> Created as '#{CBRAIN::DRMAA_SubprocessLocksDir}'"
end
Dir.chdir(CBRAIN::DRMAA_SubprocessLocksDir) do
   Dir.new(".").each do |entry|
      stat = File::Stat.new(entry)
      next unless stat.file?
      mtime = stat.mtime
      next if mtime > 1.day.ago # ignore recent files; they may still be active
      puts " -> Warning: cleaning up old subprocess lock file '#{entry}'."
      File.unlink(entry)
   end
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

# These two constants are helpful whenever we want to
# access the info about this very RAILS app.
# Note that SelfRemoteResourceId is used by SyncStatus methods.
CBRAIN::SelfRemoteResource   = bourreau
CBRAIN::SelfRemoteResourceId = bourreau.id



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
  else
    raise "CBRAIN configuration error: CLUSTER_TYPE is set to unknown value #{CBRAIN::CLUSTER_TYPE}!"
end

