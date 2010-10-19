#
# CBRAIN Project
#
# TextFile model
#
# Original author: Tarek Sherif
#
# $Id$
#

class TextFile < SingleFile

  Revision_info="$Id$"
  
  has_viewer :partial  => "text_file", :if  => :is_locally_synced?
  
  def self.file_name_pattern
    /\.txt$/i
  end
  
end
