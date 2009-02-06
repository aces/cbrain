
#
# CBRAIN Project
#
# Main CBRAIN-specific configuration file for Bourreau
#
# Original author: Pierre Rioux
#
# $Id: cbrain.rb 40 2008-11-03 20:30:49Z tsherif $
#

require 'socket'

class CBRAIN

  public

  Revision_info="$Id: cbrain.rb 40 2008-11-03 20:30:49Z tsherif $"

  # Configuration constants that depend on the hostname
  hostname = Socket.gethostname
  case hostname

    #----  CLUMEQ  ----

    when "krylov.clumeq.mcgill.ca"   # CLUMEQ
      # Filevault constants
      Filevault_host           = "montague.bic.mni.mcgill.ca"
      Filevault_user           = "prioux"
      Filevault_dir            = "/home/prioux/CBRAIN/trunk/FileVault"

      # Local bourreau constants
      DRMAA_sharedir           = "/home/prioux/CBrain/gridshare"
      Vaultcache_dir           = "/home/prioux/CBrain/FileVaultCache"

      # Software installation paths
      Quarantine_dir           = "/home/clepage/quarantines/Linux-x86_64/Feb-14-2008"
      CIVET_dir                = "/home/clepage/quarantines/Linux-x86_64/CIVET-1.1.9"

      # Establish tunnel
      system("ssh -n -f -N -R 3050:localhost:3050 prioux@montague.bic.mni.mcgill.ca")

      # TODO Environment to be set using variables ?
      ENV['LD_LIBRARY_PATH']   = "/usr/pbs/lib64:/home/prioux/drmaa/lib:/usr/lib64:/usr/lib64/mysql:/home/prioux/share/lib:/usr/X11R6/lib/X11:/usr/X11R6/lib:/usr/lib/X11:/usr/lib:/usr/lib:/usr/ucblib:/usr/local/lib/X11"

    #----  HUIA  ----

    when "huia.bic.mni.mcgill.ca"
      # Filevault constants
      Filevault_host           = "localhost"
      Filevault_user           = ""  # not used, since it's on localhost
      Filevault_dir            = "/home/cbrain/CBrainPortal/FileVault"

      # Local bourreau constants
      DRMAA_sharedir           = "/home/sge/gridshare"
      Vaultcache_dir           = ""  # not used, since it's local

      # Software installation paths
      Quarantine_dir           = "/usr/local/bic"
      CIVET_dir                = "/usr/local/bic/CIVET"

    #----  PIERRE'S  ----

    when /montague/
      # Filevault constants
      Filevault_host           = "localhost"
      Filevault_user           = ""  # not used, since it's on localhost
      Filevault_dir            = "/home/prioux/CBRAIN/trunk/FileVault"

      # Local bourreau constants
      DRMAA_sharedir           = "/opt/gridengine/gridshare"
      Vaultcache_dir           = ""  # not used, since it's local

      # Software installation paths
      Quarantine_dir           = "/usr/local/bic"
      CIVET_dir                = "/usr/local/bic/CIVET"

    #----  TAREK'S  ----

    when "tbox.local"      # Tarek's machine; bourreau doesn't work locally
      # Filevault constants
      Filevault_host           = "localhost"
      Filevault_user           = ""  # not used, since it's on localhost
      Filevault_dir            = "/Users/Tarek/Code/rails/trunk/BrainPortal/vault"

      # Bourreau constants
      DRMAA_sharedir           = "/Users/Tarek/Code/create_this/anywhere/with/mode/4755"
      Vaultcache_dir           = ""  # not used, since it's local

      # Software installation paths
      Quarantine_dir           = "/usr/local/bic"
      CIVET_dir                = "/usr/local/bic/CIVET"

    #-------------------

    else
      raise "Configuration error: unsupported Bourreau hostname '#{hostname}'."

  end

  # This variable is used to optimize the case when Bourreau
  # runs on the same server as BrainPortal
  FilevaultIsLocal = (Filevault_host == "localhost" || hostname == Filevault_host)

  # Run-time checks
  if FilevaultIsLocal
    unless File.directory?(Filevault_dir)
      raise "CBRAIN configuration error: file vault '#{Filevault_dir}' does not exist!"
    end
  else # we use a local cache instead
    unless File.directory?(Vaultcache_dir)
      raise "CBRAIN configuration error: vault cache '#{Vaultcache_dir}' does not exist!"
    end
  end

end

