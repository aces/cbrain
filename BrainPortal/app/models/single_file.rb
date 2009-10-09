
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
  
  Revision_info="$Id$"

  # Returns a simple keyword identifying the type of
  # the userfile; used mostly by the index view.
  def pretty_type
    ""
  end
  
  #Checks whether the size attribute have been set.
  def size_set?
    ! self.size.blank?
  end
  
  #Calculates and sets the size attribute.
  def set_size
    local_sync = self.local_sync_status
    unless local_sync && local_sync.status == "InSync"
      self.sync_to_cache
    end
    
    Dir.chdir(self.cache_full_path.parent) do
      self.size = File.size(self.name)
      self.save!
    end
  end

end
