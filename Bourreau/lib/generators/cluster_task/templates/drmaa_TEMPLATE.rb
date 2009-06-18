
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

# GENERAL INSTRUCTIONS:
# 
# There are three methods that need to be completed, setup(),
# drmaa_commands() and save_results(). These methods have the following
# properties:
# 
#   a) They will all be invoked while ruby's current directory has already
#      been changed to a work directory that is 'grid-aware' (usually,
#      a subdirectory shared by the nodes).
# 
#   b) They all receive in their 'params' attribute a hash table containing
#      the key-value pairs constructed on the BrainPortal side.
# 
#   c) Except for drmaa_commands(), they should all return true when
#      everything is OK. A false return value in setup() or save_results()
#      will cause the object to be stuck to the state "Failed To Setup"
#      or "Failed To Postprocess", respectively.
# 
#   d) The method drmaa_commands() must returns an array of shell commands.
# 
#   e) The method setup() MUST call the method
#      pre_synchronize_userfile(userfile) once for each userfile that it
#      will need to access; this will have the effect of scheduling a rsync
#      command to synchronize the userfile's content on the BrainPortal's
#      host with the local cache. IMPORTANT: the rsync command is run
#      JUST BEFORE the commands returned by drmaa_commands() are executed
#      as a cluster job, not when pre_synchronize_userfile() is called!
#      This means that the .name() and .vaultname() methods of Userfile
#      could return path to files that do not yet exist locally!
# 
#   f) The method save_results() MUST call the method
#      post_synchronize_userfile(userfile) once on any userfile it creates
#      or updates. This will schedule a rsync command to synchronized the
#      userfile's content back to the BrainPortal's host.


class <%= "Drmaa#{class_name}" %> < DrmaaTask

  Revision_info="$Id$"

  def setup
    params       = self.params
    user_id      = self.user_id
    true
  end

  def drmaa_commands
    params       = self.params
    user_id      = self.user_id
    [
      "<%= name %>",
      "true"
    ]
  end

  def save_results
    params       = self.params
    user_id      = self.user_id
    true
  end

end

