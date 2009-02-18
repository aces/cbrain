
#
# CBRAIN Project
#
# Main CBRAIN-specific configuration file for BrainPortal
#
# Original author: Pierre Rioux
#
# $Id$
#

require 'socket'

class CBRAIN

  public

  Revision_info="$Id$"
  Redmine_Version="0.4"

  # BrainPortal constants
  Bourreau_task_resource_URL = "http://localhost:3050/"
  #Bourreau_task_resource_URL = "http://krylov.clumeq.mcgill.ca:3050/" # does not work, need tunnelling

  # Configuration constants that depend on the hostname
  hostname = Socket.gethostname
  case hostname

    #----  HUIA  ----

    when "huia.bic.mni.mcgill.ca"

      Filevault_dir            = "/home/cbrain/CBrainPortal/FileVault"

    #----  PIERRE'S  ----

    when /montague/

      Filevault_dir            = "/home/prioux/CBRAIN/FileVault"

    #----  TAREK'S  ----

    when "tbox.local"

      Filevault_dir            = "/Users/Tarek/Code/rails/trunk/BrainPortal/vault"

    #-------------------

    else
      raise "Configuration error: unsupported BrainPortal hostname '#{hostname}'."

  end

  # Run-time checks
  unless File.directory?(Filevault_dir)
    raise "CBRAIN configuration error: file vault '#{Filevault_dir}' does not exist!"
  end

  # Other constants that are used in Bourreau but not in BrainPortal,
  # yet must still be initialized for BrainPortal to run.
  Filevault_host   = "localhost"   # dummy; brain portal doesn't need this
  Filevault_user   = ""            # dummy; brain portal doesn't need this
  Vaultcache_dir   = ""            # dummy; brain portal doesn't need this
  FilevaultIsLocal = true;         # not dummy, must be 'true'.

end

