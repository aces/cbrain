
#
# CBRAIN Project
#
# Original author: Pierre Rioux
#
# $Id$
#

class RemoteResource < ActiveRecord::Base

  Revision_info="$Id$"

  validates_uniqueness_of :name
  validates_presence_of   :name, :user_id, :group_id

  validate :valid_name?  # makes sure the name is a simple identifier

  belongs_to  :user
  belongs_to  :group

  def can_be_accessed_by(user)
    user.group_ids.include?(group_id)
  end

  def is_alive?
    false
  end

  protected

  # Makes sure that the record has a valid simple name
  def valid_name? #:nodoc:
    name = self.name
    return false unless name && name.match(/^[a-zA-Z0-9][\w\-\=\.\+]*$/)
    true
  end

end
