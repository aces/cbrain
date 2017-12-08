<% if @_license_text.present? -%>

<%= @_license_text -%>
<% end -%>

# A subclass of CbrainTask::ClusterTask to run <%= class_name %>.
class <%= "CbrainTask::#{class_name}" %> < ClusterTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  ################################################################
  # For full documentation on how to write CbrainTasks,
  # read the CBRAIN CbrainTask Programmer Guide (CBRAIN Wiki).
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
    params       = self.params
    true
  end

  # See the CbrainTask Programmer Guide
  def cluster_commands #:nodoc:
    params       = self.params
    [
      "# This is a bash script for my scientific job",
      "echo Run the <%= file_name %> command here",
      "/bin/true"
    ]
  end

  # See the CbrainTask Programmer Guide
  def save_results #:nodoc:
    params       = self.params
    true
  end

  # Add here the optional error-recovery and restarting
  # methods described in the documentation if you want your
  # task to have such capabilities. See the methods
  # recover_from_setup_failure(), restart_at_setup() and
  # friends, described in the CbrainTask Programmer Guide.

end

