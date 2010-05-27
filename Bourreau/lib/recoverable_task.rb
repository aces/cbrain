
#
# CBRAIN Project
#
# Module containing common methods for the CbrainTask::ClusterTask
# subclasses that are naturally recoverable.
#
# Original author: Pierre Rioux
#
# $Id$
#

module RecoverableTask

  Revision_info="$Id$"

  # Just returns true; it's the responsability
  # of the CbrainTask developer to write the
  # setup() method such that it recovers from
  # failure naturally.
  def recover_from_setup_failure
    true
  end

  # Just returns true; it's the responsability
  # of the CbrainTask developer to write the
  # bash commands returned by the cluster_commands() method
  # such that they recover from failure naturally.
  def recover_from_cluster_failure
    true
  end

  # Just returns true; it's the responsability
  # of the CbrainTask developer to write the
  # save_results() method such that it recovers from
  # failure naturally.
  def recover_from_post_processing_failure
    true
  end

end

