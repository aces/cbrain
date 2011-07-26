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

  Revision_info=CbrainFileRevision[__FILE__]
  
  def self.file_name_pattern
    /\.xml$/i
  end
  
end