
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

  Revision_info=CbrainFileRevision[__FILE__]

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
         tc = ToolConfig.where( myattributes ).first
         if tc
           puts "Exists OK"
           next
         end
         tc = ToolConfig.new( myattributes )
         env_array = []
         env_array << [ "MNI_QUARANTINE_ROOT", CBRAIN::Quarantine_dir ]
         env_array << [ "MNI_CIVET_ROOT",      CBRAIN::CIVET_dir      ] if toolname =~ /civet/i
         tc.env_array = env_array
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

  def self.a022_ensure_more_configuration_variables_are_unset
    
    old_Constants = {
                       'DataProviderCache_dir'           => :dp_cache_dir,
                       'DataProviderCache_RevNeeded'     => nil,
                       'DataProvider_IgnorePatterns'     => :dp_ignore_patterns,
                       'CLUSTER_sharedir'                => :cms_shared_dir,
                       'BOURREAU_CLUSTER_NAME'           => nil,
                       'CLUSTER_TYPE'                    => :cms_class,
                       'DEFAULT_QUEUE'                   => :cms_default_queue,
                       'EXTRA_QSUB_ARGS'                 => :cms_extra_qsub_args,
                       'BOURREAU_WORKERS_INSTANCES'      => :workers_instances,
                       'BOURREAU_WORKERS_CHECK_INTERVAL' => :workers_chk_time,
                       'BOURREAU_WORKERS_LOG_TO'         => :workers_log_to,
                       'BOURREAU_WORKERS_VERBOSE'        => :workers_verbose
                     }

    CbrainSystemChecks.move_old_config_vars("bourreau", old_Constants)

  end
  
  def self.a050_ensure_proper_cluster_management_layer_is_loaded

    #-----------------------------------------------------------------------------
    puts "C> Loading cluster management SCIR layers..."
    #-----------------------------------------------------------------------------

    # Load the proper class for interacting with the cluster

    myself        = RemoteResource.current_resource
    cluster_type  = myself.cms_class || "(Unset)"
    cluster_class = nil
    case cluster_type
    when "SGE"                     # old keyword
      cluster_class = "ScirSge"
    when "PBS"                     # old keyword
      cluster_class = "ScirPbs"
    when "UNIX"                    # old keyword
      cluster_class = "ScirUnix"
    when "MOAB"                    # old keyword
      cluster_class = "ScirMoab"
    when "SHARCNET"                # old keyword
      cluster_class = "ScirSharcnet"
    when /Scir(\w+)/
      cluster_class = cluster_type
    else
      raise "CBRAIN configuration error: cluster type is set to unknown value '#{cluster_type}' !"
    end
    if cluster_class != cluster_type  # adjust old keywords
      myself.cms_class = cluster_class
      myself.save(true)
    end
    session = myself.scir_session
    rev = session.revision_info.svn_id_pretty_file_rev_author_date # loads it?
    puts "C> \t - Layer for '#{cluster_class}' #{rev} loaded."
  end



  def self.a060_ensure_bourreau_worker_processes_are_reported

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

end
