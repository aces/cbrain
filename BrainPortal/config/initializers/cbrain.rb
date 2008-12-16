
#
# CBRAIN Project
#
# Main CBRAIN-specific configuration file
#
# Original author: Pierre Rioux
#
# $Id: cbrain.rb 40 2008-11-03 20:30:49Z tsherif $
#

# CBRAIN deployment constants
# This file is used both by BrainPortal and Bourreau

require 'socket'

class CBRAIN

  public

  Revision_info="$Id: cbrain.rb 40 2008-11-03 20:30:49Z tsherif $"

  # BrainPortal constants

  # Bourreau constants
  Bourreau_execution_URL     = "http://localhost:3050/"
  Bourreau_task_resource_URL = "#{Bourreau_execution_URL}"
  

  # Configuration constants that depend on the hostname
  case Socket.gethostname

    when /huia/i            # Deployment server
      # BrainPortal constants
      Filevault_dir            = "/home/cbrain/CBrainPortal/FileVault"

      # Bourreau constants
      DRMAA_sharedir           = "/home/sge/gridshare"

    when /montague/i        # Pierre's machine
      # BrainPortal constants
      Filevault_dir            = "/home/prioux/CBRAIN/trunk/FileVault"

      # Bourreau constants
      DRMAA_sharedir           = "/opt/gridengine/gridshare"

    when /tbox.local/i      # Tarek's machine
      # BrainPortal constants
      Filevault_dir            = "/Users/Tarek/Code/rails/trunk/BrainPortal/vault"

      # Bourreau constants
      DRMAA_sharedir           = "/Users/Tarek/Code/create_this/anywhere/with/mode/4755"

    else
      raise "Configuration error: unknown hostname"

  end

  # Run-time checks
  unless File.directory?(Filevault_dir) # todo: check only for BrainPortal
      raise "CBRAIN configuration error: file vault #{Filevault_dir} does not exist!"
  end

end

class String

  def svn_id_rev
    if revm = self.match(/\s+(\d+)\s+/)
      revm[1]
    else
      "(rev?)"
    end
  end

  def svn_id_file
    if revm = self.match(/^\$Id:\s+(.*?)\s+\d+/)
      revm[1]
    else
      "(fn?)"
    end
  end

  def svn_id_date
    if revm = self.match(/(\d\d\d\d-\d\d-\d\d)/)
      revm[1]
    else
      "(fn?)"
    end
  end

  def svn_id_time
    if revm = self.match(/(\d\d:\d\d:\d\d\S*)/)
      revm[1]
    else
      "(fn?)"
    end
  end

  def svn_id_author
    if revm = self.match(/(\S*)\s+\$$/)
      revm[1]
    else
      "(fn?)"
    end
  end

end
