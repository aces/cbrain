
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

# This model represents the group specific to a user.
class UserGroup < SystemGroup

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:
  
  # Returns a hash table with labels for the UserGroups
  # contained in argument +groups+ ; the key is the group ID,
  # the value is a label in format "groupname (user_full_name)"
  def self.prepare_pretty_labels(groups=[])
   ugs = Array(groups).select { |g| g.is_a?(UserGroup) }
   g_to_full_names = UserGroup.joins(:users).where('groups.id' => ugs.map(&:id)).select(['groups.id', 'groups.name', 'users.full_name']).all
   #g_to_full_names = UserGroup.joins(:users).where('groups.id' => ugs.map(&:id)).select(['groups.id', 'groups.name', 'users.login']).all
   gid_to_labels = {}
   g_to_full_names.each do |g|
     gid_to_labels[g.id] = "#{g.name}" + (g.full_name.present? ? " (#{g.full_name})" : "")
     #gid_to_labels[g.id] = "#{g.name}" + (g.login.present? ? " (#{g.login})" : "")
   end
   gid_to_labels
  end

end
