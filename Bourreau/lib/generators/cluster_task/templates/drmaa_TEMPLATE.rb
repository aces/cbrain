
#
# CBRAIN Project
#
# <%= "Drmaa#{class_name}" %> subclass for running <%= name %>
#
# Original author:
# Template author: Pierre Rioux
#
# $Id$
#

#
# GENERAL INSTRUCTIONS:
# 
# There are three methods that need to be completed:
#
#     setup(),
#     drmaa_commands() and
#     save_results().
#
# These methods have the following properties:
# 
#   a) They will all be invoked while Ruby's current directory has already
#      been changed to a work directory that is 'grid-aware' (usually,
#      a subdirectory shared by the nodes).
# 
#   b) They all receive in their 'params' attribute a hash table containing
#      the key-value pairs constructed on the BrainPortal side.
# 
#   c) Except for drmaa_commands(), they should all return true when
#      everything is OK. A false return value in setup() or save_results()
#      will cause the object to be stuck to the state "Failed To Setup"
#      or "Failed On Cluster", respectively.
# 
#   d) The method drmaa_commands() must returns an array of shell commands.
# 
#   e) Make sure you call the appropriate file synchronization methods
#      for your input files and output files. For files in input,
#      you can call userfile.sync_to_cache and get a path to the cached
#      content with userfile.cache_full_path; for files in output,
#      we recommand you simply call userfile.cache_copy_from_local_file
#      (for both SingleFile and FileCollections) and the syncronization
#      steps will be performed for you.
#
# There are several additional and OPTIONAL methods that can be implemented
# to provide the DrmaaTask with some error-recovery and partial restarting 
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
# The run_number attribute of the task will stay the same for
# the recover_* operations, while it will be increased by 1
# for the restart_* operations (after the restart method is called
# and has returned true).
#
# In addition, all tasks have always the ability to recover from
# failures in prerequisites, and all tasks can be restarted from
# scratch in a new work directory on the same Bourreau or on another
# one.

# A subclass of DrmaaTask to run <%= file_name %>.
class <%= "Drmaa#{class_name}" %> < DrmaaTask

  Revision_info="$Id$"

  # See DrmaaTask.
  def setup
    params       = self.params
    user_id      = self.user_id
    true
  end

  # See DrmaaTask.
  def drmaa_commands
    params       = self.params
    user_id      = self.user_id
    [
      "# This is a bash script for my scientific job",
      "<%= name %>",
      "/bin/true"
    ]
  end
  
  # See DrmaaTask.
  def save_results
    params       = self.params
    user_id      = self.user_id
    true
  end

  # Add here the optional error-recovery and restarting
  # methods described in the documentation if you want your
  # task to have such capabilities. See the methods
  # recover_from_setup_failure(), restart_at_setup() and friends.

end

