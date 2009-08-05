
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
  
  #Format size for display in the view.
  #Returns the size as "<tt>nnn bytes</tt>" or "<tt>nnn KB</tt>" or "<tt>nnn MB</tt>" or "<tt>nnn GB</tt>".
  def format_size
    if self.size > 10**9
      "#{self.size/10**9} GB"
    elsif   self.size > 10**6
      "#{self.size/10**6} MB"
    elsif   self.size > 10**3
      "#{self.size/10**3} KB"
    else
      "#{self.size} bytes"     
    end 
  end

  # Returns a simple keyword identifying the type of
  # the userfile; used mostly by the index view.
  def pretty_type
    ""
  end

end
