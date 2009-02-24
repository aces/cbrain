
#
# CBRAIN Project
#
# DrmaaTask subclass; this file is a TEMPLATE for creating a
# new processing class.
#
# Original author: Pierre Rioux
#
# $Id$
#

# GENERAL INSTRUCTIONS:
# 
# There are three methods that needs to be completed, setup(),
# drmaa_commands() and save_results(). These methods have the following
# properties:
# 
#   a) They will all be invoked while ruby's current directory has already
#      been changed to a work directory that is 'grid-aware' (usually,
#      a subdirectory shared by the nodes)
# 
#   b) They all receive in their 'params' attribute a hash table containing
#      the key-value pairs constructed on the BrainPortal side
# 
#   c) Except for drmaa_commands(), they should all return true when
#      everything is OK. A false return value in setup() or save_results()
#      will cause the object to be stuck to the state "Failed To Setup"
#      or "Failed To Postprocess", respectively.
# 
#   d) The method drmaa_commands() returns an array of shell commands.
# 
#   e) The method setup() MUST call once the method
#      pre_synchronize_userfile(userfile) on any userfile that it will
#      need to access; this will have the effect of scheduling a rsync
#      command to synchronize the userfile's content on the BrainPortal's
#      host with the local cache. IMPORTANT: the rsync command is run
#      JUST BEFORE the commands returned by drmaa_commands() are executed
#      as a cluster job, not when pre_synchronize_userfile() is called!
#      This means that the .name() and .vaultname() methods of Userfile
#      could return path to files that do not yet exist locally!
# 
#   f) The method save_results() MUST call once the method
#      post_synchronize_userfile(userfile) on any userfile it creates or
#      updates. This will schedule a rsync command to synchronized the
#      userfile's content back to the BrainPortal's host.

# Class declaration: You need to replace the word TEMPLATE by a name
# for the type of processing you try to accomplish.  E.g. DrmaaCivet or
# DrmaaMinc2jiv ; casing is important, it must work with the camelize()
# and uncamelize() Rails functions. Also, the name of the file must be
# adjusted accordingly.
class DrmaaTEMPLATE < DrmaaTask

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
      "echo Shell Command",
      "true"
    ]
  end

  def save_results
    params       = self.params
    user_id      = self.user_id
    true
  end

end

