
#
# CBRAIN Project
#
# Main CBRAIN-specific configuration file for Bourreau
#
# Original author: Pierre Rioux
#
# $Id$
#

class CBRAIN
    
  public

  Revision_info="$Id$"
  Redmine_Version="1.1.5"

  # Utility constants
  Startup_LocalTime = Time.now.localtime
  Rails_UserId      = Process.uid
  Rails_UserName    = Etc.getpwuid(Rails_UserId).name
  Rails_UserHome    = Etc.getpwuid(Rails_UserId).dir

end

