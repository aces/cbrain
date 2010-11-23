#
# CBRAIN Project
#
# $Id$
#

class BashSourceFile < TextFile

  Revision_info="$Id$"
  
  def self.pretty_type
    "Bash script"
  end

  def self.file_name_pattern
    /\.sh$/i
  end
  
end
