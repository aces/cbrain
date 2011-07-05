
#
# CBRAIN Project
#
# Single file model
# Represents an entry in the userfile table that corresponds to a single file.
#
# Original author: Tarek Sherif
#
# $Id$
#

require 'fileutils'

#Represents a single file uploaded to the system (as opposed to a FileCollection).
class SingleFile < Userfile
  
  Revision_info=CbrainFileRevision[__FILE__]
  
  # Forces calculation and setting of the size attribute.
  def set_size!
    self.size = self.list_files.inject(0){ |total, file_entry|  total += file_entry.size }
    self.save!

    true
  end

end
