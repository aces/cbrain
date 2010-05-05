
#
# CBRAIN Project
#
# Module containing common methods for the DrmaaTask classes
# that are naturally recoverable.
#
# Original author: Pierre Rioux
#
# $Id$
#

module RecoverableTask

  # Just returns true; it's the responsability
  # of the DrmaaTask developer to write the
  # setup() method such that it recovers from
  # failure naturally.
  def recover_from_setup_failure
    true
  end

  # Just returns true; it's the responsability
  # of the DrmaaTask developer to write the
  # bash commands returned by the drmaa_commands() method
  # such that they recover from failure naturally.
  def recover_from_cluster_failure
    true
  end

  # Just returns true; it's the responsability
  # of the DrmaaTask developer to write the
  # save_results() method such that it recovers from
  # failure naturally.
  def recover_from_post_processing_failure
    true
  end

end

