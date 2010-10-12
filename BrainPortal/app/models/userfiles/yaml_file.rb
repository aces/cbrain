#
# CBRAIN Project
#
# YAMLFile model
#
# Original author: Tarek Sherif
#
# $Id$
#

class YAMLFile < TextFile

  Revision_info="$Id$"
  
  def self.file_name_pattern
    /\.yml$/i
  end

end