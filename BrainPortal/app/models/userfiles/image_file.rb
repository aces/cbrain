#
# CBRAIN Project
#
# ImageFile model
#
# Original author: Tarek Sherif
#
# $Id$
#

class ImageFile < SingleFile

  Revision_info=CbrainFileRevision[__FILE__]
  
  has_viewer :partial  => "image_file", :if  => :is_locally_synced?
  
  def self.file_name_pattern
    /\.(jpe?g|gif|png)$/i
  end
  
end