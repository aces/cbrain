
#
# CBRAIN Project
#
# CBRAIN extensions for revision strings
#
# Original author: Pierre Rioux
#
# $Id$
#

class Object

  def self.revision_info
    if self.const_defined?("Revision_info")
      self.const_get("Revision_info")
    else
      "$" + "Id: unknownFile 0 0000-00-00 00:00:00Z unknownAuthor " + "$"
    end
  end

  def revision_info
    self.class.revision_info
  end

end

class String

  Revision_info="$Id$"

  def svn_id_rev
    if revm = self.match(/\s+(\d+)\s+/)
      revm[1]
    else
      "(rev?)"
    end
  end

  def svn_id_file
    if revm = self.match(/^\$Id:\s+(.*?)\s+\d+/)
      revm[1]
    else
      "(file?)"
    end
  end

  def svn_id_date
    if revm = self.match(/(\d\d\d\d-\d\d-\d\d)/)
      revm[1]
    else
      "(date?)"
    end
  end

  def svn_id_time
    if revm = self.match(/(\d\d:\d\d:\d\d\S*)/)
      revm[1]
    else
      "(time?)"
    end
  end

  def svn_id_author
    if revm = self.match(/(\S*)\s+\$$/)
      revm[1]
    else
      "(author?)"
    end
  end

  def svn_id_pretty_rev_date_time
    self.svn_id_rev + " " + self.svn_id_date + " " + self.svn_id_time
  end

  def svn_id_pretty_author_rev
    self.svn_id_author + " " + self.svn_id_rev
  end

  def svn_id_pretty_rev_author_date
    self.svn_id_rev + " " + self.svn_id_author + " " + self.svn_id_date
  end

end
