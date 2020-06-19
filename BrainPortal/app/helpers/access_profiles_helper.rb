
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

# Helper methods for Access Profile views.
module AccessProfilesHelper

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Generates a pretty colored label for an access profile
  def access_profile_label(access_profile, options={})
    if access_profile.name.blank?
      return ''
    end

    color  = access_profile.color.presence || "white";
    label  = "<span class=\"access_profile_label\" style=\"background: #{color}\">"
    label += options[:with_link] ? link_to_access_profile_if_accessible(access_profile) : access_profile.name
    label += "</span>"
    label.html_safe

  end

end
