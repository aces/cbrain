
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

#Helper methods for User views
module UsersHelper

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # View helper to create a valid array for a role selection box on the
  # user create and edit pages.
  def roles_for_user(user)
    roles = [["Normal User", "NormalUser"],["Site Manager","SiteManager"]]

    if user.has_role? :admin_user
      roles << ["Admin User","AdminUser"]
      roles << ["Automated User", "AutomatedUser"]
    end

    roles
  end

end
