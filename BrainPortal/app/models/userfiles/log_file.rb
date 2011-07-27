
#
# CBRAIN Project
#
# Logfile model
#
# $Id$
#

class LogFile < TextFile

  Revision_info=CbrainFileRevision[__FILE__]
  
  def self.file_name_pattern
    /\.log$/i
  end
  
end

