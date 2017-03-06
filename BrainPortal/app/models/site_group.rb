
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

# This model represents an group composed of the members
# of a Site.
class SiteGroup < SystemGroup

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Returns a hash table with labels for the SiteGroups
  # contained in argument +groups+ ; the key is the group ID,
  # the value is a label in format "groupname (site_description_first_line)"
  def self.prepare_pretty_labels(groups=[])
   ugs = Array(groups).select { |g| g.is_a?(SiteGroup) }
   g_to_desc = SiteGroup.joins(:site).where('groups.id' => ugs.map(&:id)).select(['groups.id', 'groups.name', 'sites.description']).all
   gid_to_labels = {}
   g_to_desc.each do |g|
     label = g.name
     group_site_header = g.description.lines.first.strip rescue ""
     group_site_header = sprintf("%20.20s...",group_site_header) if group_site_header.size > 20
     label += " (#{group_site_header})" if group_site_header.present?
     gid_to_labels[g.id] = label.force_encoding('UTF-8')
   end
   gid_to_labels
  end

  def can_be_edited_by?(user) #:nodoc:
    if user.has_role? :admin_user
      return true
    end

    false
  end

end

