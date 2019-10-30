
#
# CBRAIN Project
#
# Copyright (C) 2008-2012
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

#This model represents a group created automatically by the system (as opposed to WorkGroup).
#Currently, these groups include:
#[*everyone*]
#   The group representing all users on the system.
#[<b>single user groups</b>]
#   These groups are meant to represent a single individual user.
#   They are created when a user is created and use the user's login as their name.
#
#These groups are *not* meant to be modified.
class SystemGroup < Group

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  validates_uniqueness_of :name, :scope => :type

  private

  # All system groups considered created by admin
  def set_default_creator #:nodoc:
    admin_user = User.find_by_login("admin")
    if admin_user && self.creator_id != admin_user.id #if admin doesn't exist it should mean that it's a new system.
      self.creator_id = admin_user.id
    end
  end

end
