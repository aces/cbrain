
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



  #Checks for a proper timezone configuration in Rails' environment.
  def self.a009_check_if_timezone_configured

    #-----------------------------------------------------------------------------
    puts "C> Checking for proper time zone configuration..."
    #-----------------------------------------------------------------------------
    
    if ! Time.zone.blank?
      puts "C>\t- Time zone set to '#{Time.zone.name}'."
    else
      print <<-"TZ_ERROR"
C>
C> Error: Time Zone configuration incomplete!
C>
C> For this application to work, you must make sure that the
C> Rails application has the proper time zone configured
C> in this file:
C>
C>   #{RAILS_ROOT}/config/environment.rb
C>
C> Edit the file and change this line so it says:
C>
C>   config.time_zone = "your time zone name"
C>
C> The full list of time zone names can be obtained by
C> running the rake task:
C>
C>   rake time:zones:all
C>
C> and a more particular subset of acceptable names
C> for your current machine can be seen by running
C>
C>   rake time:zones:local
C>
      TZ_ERROR
      Kernel.exit(1)
    end
  end



  def self.a010_ensure_configuration_variables_are_set
    
    #-----------------------------------------------------------------------------
    puts "C> Verifying configuration variables..."
    #-----------------------------------------------------------------------------

    needed_Constants = %w(
                       DataProviderCache_dir
                       DataProviderCache_RevNeeded
                       DataProvider_IgnorePatterns
                       CLUSTER_sharedir
                       BOURREAU_CLUSTER_NAME CLUSTER_TYPE DEFAULT_QUEUE
                       EXTRA_QSUB_ARGS 
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
    unless File.directory?(CBRAIN::CLUSTER_sharedir)
      raise "CBRAIN configuration error: grid work directory '#{CBRAIN::CLUSTER_sharedir}' does not exist!"
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

    raise "CBRAIN configuration error: 'DataProvider_IgnorePatterns' is not an array!" unless
      CBRAIN::DataProvider_IgnorePatterns.is_a?(Array)

    CBRAIN::DataProvider_IgnorePatterns.each do |pattern|
      raise "Configuration error: the pattern '#{pattern}' in 'DataProvider_IgnorePatterns' is not acceptable." if
        pattern.blank? ||
        pattern == "*" ||
        ! pattern.is_a?(String) ||
        pattern =~ /\*\*/ ||
        pattern =~ /\// ||
        pattern !~ /^[\w\-\.\+\=\@\%\&\:\,\~\*\?]+$/ # very strict! other special characters can cause shell side-effects!
    end

    CBRAIN::DataProvider_IgnorePatterns.each do |pattern|
      puts "C>\t- DataProvider exclude pattern: '#{pattern}'"
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
    bourreau.update_attributes( :online => true )

  end



  def self.a021_ensure_old_configuration_variables_are_unset

    myself = RemoteResource.current_resource
    myname = myself.name
    myid   = myself.id

    #------------------------------------------
    # OBSOLETE EXTRA_BASH_INIT_CMDS
    #------------------------------------------

    if CBRAIN.const_defined?('EXTRA_BASH_INIT_CMDS')
      puts <<-MESSAGE

Configuration error: the CBRAIN constant 'EXTRA_BASH_INIT_CMDS' is
NO LONGER NEEDED in file 'config_bourreau.rb'. The initialization
code it contained must be configured on the portal side, here:

      http(s)://your_portal_host/tool_configs/new?bourreau_id=#{myid}

If the current content of the EXTRA_BASH_INIT_CMDS is empty
(as in, there are no real BASH commands), you can simply remove it from
the file 'config_bourreau.rb'.

      MESSAGE

      if myself.global_tool_config
        puts <<-MESSAGE
It seems that there already is a record with a configuration
for those extra commands, so you'll have to compare and adjust
the setup manually using the URL above. For your reference,
here's the content of the constant in EXTRA_BASH_INIT_CMDS:

#{CBRAIN::EXTRA_BASH_INIT_CMDS.join("\n")}

versus the config that can be edited using the interface:

#{myself.global_tool_config.script_prologue}

If they seem identical, you can simply erase EXTRA_BASH_INIT_CMDS
from the 'bourreau_config.rb'.

        MESSAGE
      else
        puts <<-MESSAGE
It seems that we can at least attempt to move the configuration
automatically! Yeah! So let's proceed...

        MESSAGE
        tc = ToolConfig.new(:bourreau_id     => myid,
                            :tool_id         => nil,
                            :script_prologue => CBRAIN::EXTRA_BASH_INIT_CMDS.join("\n")
                           )
        if tc.save
           puts "    Success! Just erase EXTRA_BASH_INIT_CMDS from 'config_bourreau.rb' now.\n\n"
        else
           puts "    Failure to copy config. You'll have to edit the config manually\n"
           puts "    using the URL above.\n"
        end
      end

      raise "Cannot proceed until 'EXTRA_BASH_INIT_CMDS' is adjusted in 'config_bourreau.rb'."
    end

    #------------------------------------------
    # OBSOLETE Quarantine_dir and CIVET_dir
    #------------------------------------------

    if CBRAIN.const_defined?('Quarantine_dir') || CBRAIN.const_defined?('CIVET_dir')

      auto_config_title = "Original MNI Quarantine"

      puts <<-MESSAGE

Configuration error: the CBRAIN constants 'Quarantine_dir' and 'CIVET_dir'
are NO LONGER NEEDED in file 'config_bourreau.rb'. Those paths
should now be configured on a tool by tool basis using the interface.
The MNI tools (such as CIVET and dcm2mnc etc) require these
this path to be set as an environment variable:

    MNI_QUARANTINE_ROOT    (old value of 'Quarantine_dir')

This is performed by going to the 'Tool' menu, clicking 'edit'
for each MNI tool, then in the form clicking the link 'Add new'
in the section 'Version Configuration' for this cluster. Add the
environment variable and the following BASH initialization
prologue:

    source "$MNI_QUARANTINE_ROOT/init.sh"

In the case of tools CIVET and CIVET_qc, there needs one
to be one more environment variable and one more line in the
prologue of the same configuration:

    MNI_CIVET_ROOT         (old value of 'CIVET_dir')

    export PATH="$MNI_CIVET_ROOT:$PATH"

This validation script will now automatically attempt to
create all the configurations for all known MNI
tools. In the report below, if you find that all tools
show the status 'Newly Created' or 'Exists OK', then
it means you can simply remove the two constants from
the 'bourreau_config.rb' file. Otherwise, you'll have
to check the configurations manually using the interface,
as explained above. The configurations created will
be named: '#{auto_config_title}'

      MESSAGE

      mni_tools = %w( civet civet_qc cw5 cw5filter
                      dcm2mnc minc2jiv mincaverage mincmath mincpik
                      mincresample mnc2nii nii2mnc )

      has_problems = []
      mni_tools.each do |toolname|
         toolclass     = toolname.classify
         fulltoolclass = "CbrainTask::#{toolclass}"
         print sprintf("    %15s : ",toolclass)
         tool = Tool.find_by_cbrain_task_class(fulltoolclass)
         if ! tool
           puts "Failed: can't find Tool associated to this class?"
           has_problems << toolclass
           next
         end
         desc = <<-DESCRIPTION
#{auto_config_title}

This configuration represents the
original MNI Quarantine installed
on this cluster. Created automatically
by the Execution Server's validation
script when CBRAIN was upgraded.
         DESCRIPTION
         script  = "source \"$MNI_QUARANTINE_ROOT/init.sh\"\n"
         script += "export PATH=\"$MNI_CIVET_ROOT:$PATH\"\n" if toolname =~ /civet/i
         myattributes = {
            :tool_id         => tool.id,
            :bourreau_id     => myid,
            :description     => desc,
            :script_prologue => script
         }
         tc = ToolConfig.find(:first, :conditions => myattributes)
         if tc
           puts "Exists OK"
           next
         end
         tc = ToolConfig.new(myattributes)
         env_hash = {}
         env_hash["MNI_QUARANTINE_ROOT"] = CBRAIN::Quarantine_dir
         env_hash["MNI_CIVET_ROOT"]      = CBRAIN::CIVET_dir if toolname =~ /civet/i
         tc.env_hash = env_hash
         if tc.save
           puts "Created"
         else
           puts "Failed: can't save object:\n#{tc.errors.full_messages}"
           has_problems << toolclass
         end
      end

      if has_problems.size == 0
         puts <<-MESSAGE
 
It seems all the tools were properly auto configured! Yeah!
You can simply erase completely the two constants 'Quarantine_dir'
and 'CIVET_dir' from the 'bourreau_config.rb' file.

         MESSAGE
      else
         puts <<-MESSAGE

It seems some tools could not properly be configured automatically.
The problem tools, as listed above, are:

    #{has_problems.join(", ")}

Adjust them using the Portal interface then erase the two constants
'Quarantine_dir' and 'CIVET_dir' in  the 'bourreau_config.rb' file.

         MESSAGE
      end

      raise "Cannot proceed until 'Quarantine_dir' and 'CIVET_dir' are adjusted in 'config_bourreau.rb'."

    end

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
          newname = ".#{entry}_being_deleted.#{Process.pid}"
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
      puts "C> \t - No worker processes found. It's OK, they'll be started as needed."
    else
      puts "C> \t - Scheduling restart for all of them ..."
      allworkers.stop_workers
    end
  end



  def self.a080_ensure_set_starttime_revision

    $CBRAIN_StartTime_Revision = RemoteResource.current_resource.info.revision
    #-----------------------------------------------------------------------------
    puts "C> Current Remote Resource revision number: #{$CBRAIN_StartTime_Revision}"
    #-----------------------------------------------------------------------------

  end

end
