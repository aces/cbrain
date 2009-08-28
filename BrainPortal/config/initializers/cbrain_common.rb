
#
# CBRAIN Project
#
# CBRAIN configuration values common to both BrainPortal and Bourreau
#
# Original author: Pierre Rioux
#
# $Id$
#

class CBRAIN
    
  public

  # Utility constants
  Startup_LocalTime = Time.now.localtime
  Rails_UserId      = Process.uid
  Rails_UserName    = Etc.getpwuid(Rails_UserId).name
  Rails_UserHome    = Etc.getpwuid(Rails_UserId).dir

  # Some environment variables MUST be set for some subsystems to work.
  # In deployment at McGill, we run the rails application under control
  # of 'monit' which clears the environment of almost everything!
  ENV['HOME'] = Rails_UserHome        # Most notably, Net::SFTP needs this

end

