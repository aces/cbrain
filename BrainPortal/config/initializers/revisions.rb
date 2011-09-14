
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

  # This method returns the value of the class constant
  # named 'Revision_info', if it exists; otherwise it
  # returns a default string in the same format,
  #
  #   "SId: unknownFile 0 0000-00-00 00:00:00Z unknownAuthor S"
  # 
  # (where the uppercase letters 'S' at each end are in fact '$' signs)
  def self.revision_info
    if self.const_defined?("Revision_info")
      self.const_get("Revision_info")
    else
      "$" + "Id: unknownFile 0 0000-00-00 00:00:00Z unknownAuthor " + "$"
    end
  end

  # This method returns the vlaue of the object's class constant
  # named 'Revision_info', just like the class method of the
  # same name.
  def revision_info
    self.class.revision_info
  end

end

class String

  Revision_info=CbrainFileRevision[__FILE__]

  # Given a revision info string such as
  #
  #  "$Id$"
  #
  # it will return the revision number as a string
  # (the first number after the file name). If the
  # string is unparsable, it returns "(rev?)".
  def svn_id_rev
    if revm = self.match(/\s+([\da-fA-F]+)\s+/)
      revm[1]
    else
      "(rev?)"
    end
  end

  # Given a revision info string such as
  #
  #  "$Id$"
  #
  # it will return the filename. If the
  # string is unparsable, it returns "(file?)".
  def svn_id_file
    if revm = self.match(/^\$Id:\s+(\S+)/)
      revm[1]
    else
      "(file?)"
    end
  end

  # Given a revision info string such as
  #
  #  "$Id$"
  #
  # it will return the date (but not the time).
  # If the string is unparsable, it returns "(date?)".
  def svn_id_date
    if revm = self.match(/(\d\d\d\d-\d\d-\d\d)/)
      revm[1]
    else
      "(date?)"
    end
  end

  # Given a revision info string such as
  #
  #  "$Id$"
  #
  # it will return the time (but not the date).
  # If the string is unparsable, it returns "(time?)".
  def svn_id_time
    if revm = self.match(/(\d\d:\d\d:\d\d\S*(\s[+-]\d+)?)/)
      revm[1]
    else
      "(time?)"
    end
  end

  # Given a revision info string such as
  #
  #  "$Id$"
  #
  # it will return the author.
  # If the string is unparsable, it returns "(author?)".
  def svn_id_author
    if revm = self.match(/\d\d:\d\d:\d\d\S*(\s[+-]\d+)?\s+(\S.*\S)\s+\$$/)
      revm[2]
    else
      "(author?)"
    end
  end

  # Given a revision info string such as
  #
  #  "$Id$"
  #
  # it will return a string composed
  # of two elements concatenated:
  #
  #   "date time"
  def svn_id_datetime
    self.svn_id_date + " " + self.svn_id_time
  end

  # Given a revision info string such as
  #
  #  "$Id$"
  #
  # it will return a string composed
  # of three elements concatenated:
  #
  #   "rev date time"
  def svn_id_pretty_rev_date_time
    self.svn_id_rev + " " + self.svn_id_date + " " + self.svn_id_time
  end

  # Given a revision info string such as
  #
  #  "$Id$"
  #
  # it will return a string composed
  # of two elements concatenated:
  #
  #   "author rev"
  def svn_id_pretty_author_rev
    self.svn_id_author + " " + self.svn_id_rev
  end

  # Given a revision info string such as
  #
  #  "$Id$"
  #
  # it will return a string composed
  # of three elements concatenated:
  #
  #   "rev author date"
  def svn_id_pretty_rev_author_date
    self.svn_id_rev + " " + self.svn_id_author + " " + self.svn_id_date
  end

  # Given a revision info string such as
  #
  #  "$Id$"
  #
  # it will return a string composed
  # of four elements concatenated:
  #
  #   "file rev author date"
  def svn_id_pretty_file_rev_author_date
    self.svn_id_file + " " + self.svn_id_rev + " " + self.svn_id_author + " " + self.svn_id_date
  end

end
