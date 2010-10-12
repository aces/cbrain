#
# CBRAIN Project
#
# XMLFile model
#
# Original author: Tarek Sherif
#
# $Id$
#

class XMLFile < TextFile

  Revision_info="$Id$"
  
  def self.file_name_pattern
    /\.xml$/i
  end
  
end