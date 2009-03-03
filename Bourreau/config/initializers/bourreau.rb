
#
# CBRAIN Project
#
# Main CBRAIN-specific configuration file for Bourreau
#
# Original author: Pierre Rioux
#
# $Id$
#

require 'socket'

class CBRAIN

  public

  Revision_info="$Id$"

  # Configuration constants that depend on the hostname
  hostname = Socket.gethostname
  case hostname

    #----  CLUMEQ  ----

    when "krylov.clumeq.mcgill.ca"   # CLUMEQ
      # Filevault constants
      Filevault_host           = "huia.bic.mni.mcgill.ca"
      Filevault_user           = "cbrain"
      Filevault_dir            = "/home/cbrain/CBrainPortal/FileVault"

      # Local bourreau constants
      DRMAA_sharedir           = "/home/prioux/CBrain/gridshare"
      Vaultcache_dir           = "/home/prioux/CBrain/FileVaultCache"

      # Software installation paths
      Quarantine_dir           = "/home/clepage/quarantines/Linux-x86_64/Feb-14-2008"
      CIVET_dir                = "/home/clepage/quarantines/Linux-x86_64/CIVET-1.1.9"

      # Establish tunnel
      system("ssh -f -n -N -R 3090:localhost:3050 cbrain@huia.bic.mni.mcgill.ca")

      # TODO Environment to be set using variables ?
      ENV['LD_LIBRARY_PATH']   = "/usr/pbs/lib64:/home/prioux/drmaa/lib:/usr/lib64:/usr/lib64/mysql:/home/prioux/share/lib:/usr/X11R6/lib/X11:/usr/X11R6/lib:/usr/lib/X11:/usr/lib:/usr/lib:/usr/ucblib:/usr/local/lib/X11"
      # TODO the PERL5LIB path should maybe be set in the DrmaaTask's commands ?
      ENV['PERL5LIB'] ||= ""
      ENV['PERL5LIB'] += ":" if ENV['PERL5LIB'] != ""
      ENV['PERL5LIB'] += "/home/prioux/share/lib/perl5/site_perl/5.8.5"

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

    #----  PIERRE'S, local  ----

    when /montagueX/
      # Filevault constants
      Filevault_host           = "localhost"
      Filevault_user           = ""  # not used, since it's on localhost
      Filevault_dir            = "/home/prioux/CBRAIN/FileVault"

      # Local bourreau constants
      DRMAA_sharedir           = "/opt/gridengine/gridshare"
      Vaultcache_dir           = ""  # not used, since it's local

      # Software installation paths
      Quarantine_dir           = "/usr/local/bic"
      CIVET_dir                = "/usr/local/bic/CIVET"

    #----  MATHIEU'S, local  ----

    when /morpheus/
      # Filevault constants
      Filevault_host           = "localhost"
      Filevault_user           = ""  # not used, since it's on localhost
      Filevault_dir            = "/home/mathieu/cbrain/FileVault"

      # Local bourreau constants
      DRMAA_sharedir           = "/data/datascan/.gridshare"
      Vaultcache_dir           = ""  # not used, since it's local

      # Software installation paths
      Quarantine_dir           = "/opt/share/mni"
      CIVET_dir                = "/opt/share/mni/CIVET-1.1.9"

    #----  PIERRE'S, fake remote  ----

    when /montague/
      # Filevault constants
      Filevault_host           = "montague.bic.mni.mcgill.ca"
      Filevault_user           = "prioux"
      Filevault_dir            = "/home/prioux/CBRAIN/FileVault"

      # Local bourreau constants
      DRMAA_sharedir           = "/opt/gridengine/gridshare"
      Vaultcache_dir           = "/home/prioux/CBRAIN/VaultCache"

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
  FilevaultIsLocal = (Filevault_host == "localhost")

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

