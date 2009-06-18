
#
# CBRAIN Project
#
# CBRAIN extensions for revision strings
#
# Original author: Pierre Rioux
#
# $Id$
#

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
      "(fn?)"
    end
  end

  def svn_id_date
    if revm = self.match(/(\d\d\d\d-\d\d-\d\d)/)
      revm[1]
    else
      "(fn?)"
    end
  end

  def svn_id_time
    if revm = self.match(/(\d\d:\d\d:\d\d\S*)/)
      revm[1]
    else
      "(fn?)"
    end
  end

  def svn_id_author
    if revm = self.match(/(\S*)\s+\$$/)
      revm[1]
    else
      "(fn?)"
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
