#
# CBRAIN Project
#
# $Id$
#

class RubySourceFile < TextFile

  Revision_info=CbrainFileRevision[__FILE__]
  
  def self.pretty_type
    "Ruby source file"
  end

  def self.file_name_pattern
    /\.rb$/i
  end
  
end
