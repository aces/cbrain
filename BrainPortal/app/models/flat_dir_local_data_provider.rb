
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

# The provider's files are stored in a flat directory, one
# level deep, directly specified by the object's +remote_dir+
# attribute. The file "hello" is thus stored in a path like this:
#
#     /remote_dir/hello
#
# There is no caching in this provider: all caching methods
# access the direct path to the local file.
#
# This provider is "browsable".
#
# For the list of API methods, see the DataProvider superclass.
class FlatDirLocalDataProvider < LocalDataProvider

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # This returns the category of the data provider
  def self.pretty_category_name #:nodoc:
    "Single Level"
  end

  def is_browsable?(by_user = nil) #:nodoc:
    return true if by_user.blank? || self.meta[:browse_gid].blank?
    return true if by_user.is_a?(AdminUser) || by_user.id == self.user_id
    by_user.is_member_of_group(self.meta[:browse_gid].to_i)
  end

  def content_storage_shared_between_users? #:nodoc:
    true
  end

end

