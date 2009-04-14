
#
# CBRAIN Project
#
# Main CBRAIN-specific configuration file for BrainPortal
#
# Original author: Pierre Rioux
#
# $Id$
#

require 'socket';

class CBRAIN
    
  public

  Revision_info="$Id$"
  Redmine_Version="0.7"

  # Other constants that are used in Bourreau but not in BrainPortal,
  # yet must still be initialized for BrainPortal to run.
  Filevault_host   = "localhost"   # dummy; brain portal doesn't need this
  Filevault_user   = ""            # dummy; brain portal doesn't need this
  Vaultcache_dir   = ""            # dummy; brain portal doesn't need this
  FilevaultIsLocal = true;         # not dummy, must be 'true'.

end

