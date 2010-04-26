
#
# CBRAIN Project
#
# Bourreau System Checks
#
# Original author: Nicolas Kassis (taken from validation_portal by Pierre Rioux)
#
# $Id$
#

require 'socket'

class BourreauSystemChecks < CbrainChecker

  Revision_info="$Id$"

  def self.a010_ensure_configuration_variables_are_set
    
    #-----------------------------------------------------------------------------
    puts "C> Verifying configuration variables..."
    #-----------------------------------------------------------------------------

    needed_Constants = %w(
                       DataProviderCache_dir
                       DataProviderCache_RevNeeded
                       DRMAA_sharedir Quarantine_dir CIVET_dir 
                       BOURREAU_CLUSTER_NAME CLUSTER_TYPE DEFAULT_QUEUE
                       EXTRA_QSUB_ARGS EXTRA_BASH_INIT_CMDS
                       BOURREAU_WORKERS_INSTANCES
                       BOURREAU_WORKERS_CHECK_INTERVAL
                       BOURREAU_WORKERS_LOG_TO
                       BOURREAU_WORKERS_VERBOSE
                     )

    # Constants
    needed_Constants.each do |c|
      unless CBRAIN.const_defined?(c)
        raise "Configuration error: the CBRAIN constant '#{c}' is not defined!\n" +
          "Check 'config_bourreau.rb' (and compare it to 'config_bourreau.rb.TEMPLATE')."
      end
    end
    
    # Run-time checks
    unless File.directory?(CBRAIN::DataProviderCache_dir)
      raise "CBRAIN configuration error: Data Provider cache directory '#{CBRAIN::DataProviderCache_dir}' does not exist!"
    end
    unless File.directory?(CBRAIN::DRMAA_sharedir)
      raise "CBRAIN configuration error: grid work directory '#{CBRAIN::DRMAA_sharedir}' does not exist!"
    end
    unless File.directory?(CBRAIN::Quarantine_dir)
      raise "CBRAIN configuration error: Quarantine directory '#{CBRAIN::Quarantine_dir}' does not exist!"
    end
    unless File.directory?(CBRAIN::CIVET_dir)
      raise "CBRAIN configuration error: CIVET code directory '#{CBRAIN::CIVET_dir}' does not exist!"
    end

    if CBRAIN::BOURREAU_CLUSTER_NAME.empty? || CBRAIN::BOURREAU_CLUSTER_NAME == "nameit"
      raise "CBRAIN configuration error: this Bourreau has not been given a name!"
    else
      bourreau = Bourreau.find_by_name(CBRAIN::BOURREAU_CLUSTER_NAME)
      if bourreau
        CBRAIN.const_set('BOURREAU_ID',bourreau.id) # this is my own ID, then.
      else
        raise "CBRAIN configuration error: can't find ActiveRecord for a Bourreau with name '#{CBRAIN::BOURREAU_CLUSTER_NAME}'."
      end
    end

    if ! CBRAIN::EXTRA_BASH_INIT_CMDS.is_a?(Array) || CBRAIN::EXTRA_BASH_INIT_CMDS.find { |s| ! s.is_a?(String) }
      raise "CBRAIN configuration error: the EXTRA_BASH_INIT_CMDS is not an array of strings!"
    end


  end
  

  def self.a020_ensure_registered_as_remote_ressource
    

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
      bourreau = bourreau_by_md5
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
    
    CBRAIN.const_set('SelfRemoteResourceId',bourreau.id)

  end

  def self.a030_ensure_data_provider_caches_needs_wiping
    #-----------------------------------------------------------------------------
    puts "C> Checking to see if Data Provider caches need wiping..."
    #-----------------------------------------------------------------------------

    dp_init_rev    = DataProvider.cache_revision_of_last_init  # will be "0" if unknown
    dp_current_rev = DataProvider.revision_info.svn_id_rev
    raise "Serious Internal Error: I cannot get a numeric SVN revision number for DataProvider?!?" unless
      dp_current_rev && dp_current_rev =~ /^\d+/
    if dp_init_rev.to_i <= CBRAIN::DataProviderCache_RevNeeded # Before Pierre's upgrade
      puts "C> \t- Data Provider Caches are being wiped (Rev: #{dp_init_rev} vs #{dp_current_rev})..."
      puts "C> \t- WARNING: This could take a long time so you should not"
      puts "C> \t  start another instance of this Rails application."
      Dir.chdir(DataProvider.cache_rootdir) do
        Dir.foreach(".") do |entry|
          next unless File.directory?(entry) && entry !~ /^\./ # ignore ., .. and .*_being_deleted.*
          newname = ".#{entry}_being_deleted.#{$$}"
          renamed_ok = File.rename(entry,newname) rescue false
          if renamed_ok
            puts "C> \t\t- Removing old cache subdirectory '#{entry}' in background..."
            system("/bin/rm -rf '#{newname}' </dev/null &")
          end
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
  end

  def self.a050_ensure_proper_cluster_management_layer_is_loaded
    

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
  end


  def self.a060_ensure_bourreau_worker_precess_are_reported
    

    #-----------------------------------------------------------------------------
    puts "C> Reporting Bourreau Worker Processes (if any)..."
    #-----------------------------------------------------------------------------

    # This will reconnect with any and all workers already
    # running, for instance if Bourreau was shut down and the workers
    # were still alive.
    allworkers = WorkerPool.find_pool(BourreauWorker)
    allworkers.each do |worker|
      puts "C> \t - Found worker already running: #{worker.pretty_name} ..."
    end
    if allworkers.size == 0
      puts "C> \t - No worker process found. It's OK, they'll be started as needed."
    else
      puts "C> \t - Scheduling restart for all of them ..."
      allworkers.stop_workers
    end
  end





end
