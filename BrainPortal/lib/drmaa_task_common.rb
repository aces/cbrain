
#
# CBRAIN Project
#
# Module containing common methods for the DrmaaTask classes
# used on the BrainPortal and Bourreau side; it's important
# to realized that on the BrainPortal side, DrmaaTasks are
# ActiveResource objects, while on the Bourreau side they
# are ActiveRecords. Still, many methods are common, so they've
# been extracted here.
#
# Original author: Pierre Rioux
#
# $Id$
#


module DrmaaTaskCommon

  Revision_info="$Id$"

  # Returns the task's User
  def user
    @user ||= User.find(self.user_id)
  end

  # Returns a simple name for the task (without the Drmaa prefix).
  def name
    @name ||= self.class.to_s.gsub(/^Drmaa/,"")
  end

  def bourreau
    @bourreau ||= Bourreau.find(self.bourreau_id)
  end

  # Returns an ID string containing both the bourreau_id +b+
  # and the task ID +t+ in format "b/t"
  def bid_tid
    @bid_tid ||= "#{self.bourreau_id || '?'}/#{self.id || '?'}"
  end

  # Returns an ID string containing both the bourreau_name +b+
  # and the task ID +t+ in format "b/t"
  def bname_tid
    @bname_tid ||= "#{self.bourreau.name || '?'}/#{self.id || '?'}"
  end

  # Returns an ID string containing both the bourreau_name +b+
  # and the task ID +t+ in format "b-t" ; this is suitable to
  # be used as part of a filename.
  def bname_tid_dashed
    @bname_tid_dashed ||= "#{self.bourreau.name || 'Unk'}-#{self.id || 'Unk'}"
  end

end

