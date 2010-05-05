
#
# CBRAIN Project
#
# Module containing common methods for the DrmaaTask classes
# that are naturally restartable.
#
# Original author: Pierre Rioux
#
# $Id$
#

module RestartableTask

  # Just returns true; it's the responsability
  # of the DrmaaTask developer to write the
  # setup() method such that it can be restarted
  # naturally.
  def restart_at_setup
    true
  end

  # Just returns true; it's the responsability
  # of the DrmaaTask developer to write the
  # bash commands returned by the drmaa_commands() method
  # such that they can be restarted naturally.
  def restart_at_cluster
    true
  end

  # Just returns true; it's the responsability
  # of the DrmaaTask developer to write the
  # save_results() method such that it can be restarted
  # naturally.
  def restart_at_post_processing
    true
  end

end

