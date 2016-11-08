
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

#Helper methods for Group views.
module GroupsHelper

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Returns the appropriate CSS type for +group+
  # +group_user_count+ corresponds to how many users belong to the group. It
  # is queried from the group if not supplied.
  def css_group_type(group, group_user_count = nil)
    # Special cases ("ALL")
    return group.to_s.downcase unless group.is_a?(Group)

    # SystemGroup subclasses; UserGroup => "user", EveryoneGroup => "everyone"
    return group.class.name.demodulize.match(/\A([A-Z][a-z]+)/).to_s.downcase if group.is_a?(SystemGroup)

    group_user_count ||= group.users.count

    return "invisible" if group.invisible?
    return "empty"     if group_user_count == 0
    return "shared"    if group_user_count > 1
    return "personal"
  end

  # Produces a centered legend for every distinct group type in +groups+
  def group_legend(groups)
    return if groups.blank?

    center_legend(nil, groups.map { |g| css_group_type(g) }.uniq.map { |g|
      # 9675: UTF8 white circle, 9679: UTF8 black circle
      ["<span class=\"#{g}_project_point\">&##{g == "all" ? 9675 : 9679};</span>", "#{g.titleize} Project"]
    })
  end
end
