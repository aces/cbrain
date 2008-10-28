
#
# CBRAIN Project
#
# User model
#
# Original author: Pierre Rioux
#
# $Id$
#

class User < ActiveRecord::Base

  Revision_info="$Id$"

  @@id2name = nil    # Cache hash: id => name

  # This class methods maps user_ids to user_names
  # It caches the mappings in a class variable, so that
  # only a single hit to the database is performed
  # the first time it is called in a process' liftime
  def self.id2name(id)
    if @@id2name
      @@id2name[id]
    else
      @@id2name = Hash.new()
      allusers = User.all.each { |u| @@id2name[u.id] = u.user_name }
      @@id2name[id]
    end
  end

end
