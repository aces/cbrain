
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
#   e) Make sure you call the appropriate file syncronization methods
#      for your input files and output files. For files in input,
#      you can call userfile.sync_to_cache and get a path to the cached
#      content with userfile.cache_full_path; for files in output,
#      we recommand you simply call userfile.cache_copy_from_local_file
#      (for both SingleFile and FileCollections) and the syncronization
#      steps will be performed for you.

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

