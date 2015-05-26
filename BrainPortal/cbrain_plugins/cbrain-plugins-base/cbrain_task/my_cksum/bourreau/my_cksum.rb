
# A subclass of CbrainTask::ClusterTask to run MyCksum.
class CbrainTask::MyCksum < ClusterTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  ################################################################
  # For full documentation on how to write CbrainTasks,
  # read the CBRAIN CbrainTask Programmer's Guide (CBRAIN Wiki).
  #
  # There are typically three methods that need to be completed:
  #
  #     setup(),
  #     cluster_commands() and
  #     save_results().
  #
  # These methods have the following properties:
  #
  #   a) They will all be invoked while Ruby's current directory has already
  #      been changed to a work directory that is 'grid aware' (usually,
  #      a subdirectory shared by the nodes).
  #
  #   b) They all receive in their 'params' attribute a hash table containing
  #      the key-value pairs constructed on the BrainPortal side.
  #
  #   c) Except for cluster_commands(), they should all return true when
  #      everything is OK. A false return value in setup() or save_results()
  #      will cause the object to be stuck to the state "Failed To Setup"
  #      or "Failed On Cluster", respectively.
  #
  #   d) The method cluster_commands() must returns an array of shell commands.
  #
  #   e) Make sure you call the appropriate file synchronization methods
  #      for your input files and output files. For files in input,
  #      you can call userfile.sync_to_cache, and then get a path to the cached
  #      content with userfile.cache_full_path; for files in output,
  #      we recommand you simply call userfile.cache_copy_from_local_file
  #      (for both SingleFile and FileCollections) and the syncronization
  #      steps will be performed for you.
  #
  # There are several additional and OPTIONAL methods that can be implemented
  # to provide the CbrainTask with some error-recovery and partial restarting
  # capabilities. These are:
  #
  #   recover_from_setup_failure()            # For 'Failed To Setup'
  #   recover_from_cluster_failure()          # For 'Failed On Cluster'
  #   recover_from_post_processing_failure()  # For 'Failed To PostProcess'
  #   restart_at_setup()                      # For any non-error terminal states
  #   restart_at_cluster()                    # For any non-error terminal states
  #   restart_at_post_processing()            # For any non-error terminal states
  #
  # All of these need to return 'true' for the recovering or restarting
  # behavior to be enabled; note that by default none of them return true.
  #
  # The run_number attribute of the task will stay the same for
  # the recover_* operations, while it will be increased by 1
  # for the restart_* operations (after the restart method is called
  # and has returned true). See also the Programmer Guides (CBRAIN Wiki).
  #
  # In addition, all tasks have always the ability to recover from
  # failures in prerequisites, and all tasks can be restarted from
  # scratch in a new work directory on the same Bourreau or on another
  # one.
  #
  # Please remove all these comment blocks before committing
  # your code. Provide proper RDOC comments just before
  # each method if you want to document them, but note
  # that normally all normal API methods are #:nodoc: anyway.
  ################################################################

  ################################################################
  # Uncomment the following two lines ONLY if the task has been coded
  # to properly follow the guidelines for recovery and restartability.
  # In that case, these two modules will provide the six recover_* and
  # restart_at_* methods that simply all return true (and do nothing else!)
  ################################################################

  #include RestartableTask
  #include RecoverableTask

  # See the CbrainTask Programmer Guide
  def setup #:nodoc:
    # on the portal side, we replace this array by another one containing a single ID
    # in the method final_task_list()
    id = params[:interface_userfile_ids][0]
    # Sync file
    file = SingleFile.find(id)
    file.sync_to_cache
    # Create symlink locally, with same base name
    filename = file.name
    cached_path = file.cache_full_path
    safe_symlink(cached_path,filename) # does not mind if it already exists
    if self.tool_config.is_at_least_version('2.0.0')
      cb_error "Oh no our number isn't odd!" if (params[:an_odd_number].to_i % 2) != 1
    end
    true # must return true if all OK
  end

  # See the CbrainTask Programmer Guide
  def cluster_commands #:nodoc:
    id      = params[:interface_userfile_ids][0]
    file    = SingleFile.find(id)
    runid   = self.run_id # utility method, returns "#{task_id}-#{run_number}"
    prefix  = params[:output_file_prefix]
    outname = "#{prefix}myout-#{runid}.txt"
    [  # for historical reasons, this method should return an array of strings....
      "# bash script starts here",
      "echo This is standard output",
      "echo This is standard error 1>&2",
      "echo This is the report from my task > #{outname}",
      "cksum #{file.name} >> #{outname}"
    ]
  end

  # See the CbrainTask Programmer Guide
  def save_results #:nodoc:
    id      = params[:interface_userfile_ids][0]
    infile  = SingleFile.find(id)
    runid   = self.run_id # utility method, returns "#{task_id}-#{run_number}"
    prefix  = params[:output_file_prefix]
    outname = "#{prefix}myout-#{runid}.txt"
    cb_error "Can't find my output file '#{outname}' ?!?" unless File.exists?(outname)
    outfile = safe_userfile_find_or_new(TextFile,  # utility of ClusterTask
                { :name => outname,
                  :data_provider_id => self.results_data_provider_id.presence || infile.data_provider_id
                }
              )
    outfile.cache_copy_from_local_file(outname) # also saves to official data provider
    outfile.move_to_child_of(infile)
    self.addlog_to_userfiles_these_created_these([infile],[outfile]) # utility of ClusterTask
    self.params[:report_id] = outfile.id  # so that the show page for the task shows it
    true
  end

  # Add here the optional error-recovery and restarting
  # methods described in the documentation if you want your
  # task to have such capabilities. See the methods
  # recover_from_setup_failure(), restart_at_setup() and
  # friends, described in the CbrainTask Programmer Guide.

end

