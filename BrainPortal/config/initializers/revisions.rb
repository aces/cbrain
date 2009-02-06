
#
# CBRAIN Project
#
# CBRAIN extensions for revision strings
#
# Original author: Pierre Rioux
#
# $Id: cbrain.rb 40 2008-11-03 20:30:49Z tsherif $
#

class String

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

end
