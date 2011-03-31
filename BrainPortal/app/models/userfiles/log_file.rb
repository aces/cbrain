
#
# CBRAIN Project
#
# Logfile model
#
# $Id$
#

class LogFile < TextFile

  Revision_info="$Id$"
  
  def self.file_name_pattern
    /\.log$/i
  end
  
end

