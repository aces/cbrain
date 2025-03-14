
#
# CBRAIN Project
#
# Copyright (C) 2008-2024
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

# This class implements a LocalDataProvider
# that also has the ability to browse and register
# files in subdirectories.
#
# The DP is by default read-only because there is
# currently no way for the framework to specify
# where to put a new file on this DP.
#
# Note that registering files as subset of other files
# is discouraged and can lead to serious data inconsistencies.
class MultilevelLocalDataProvider < FlatDirLocalDataProvider

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # This returns the category of the data provider
  def self.pretty_category_name #:nodoc:
    "Multi Level"
  end

  def has_browse_path_capabilities? #:nodoc:
    true
  end

  # Returns true: forces this DP type to be read-only.
  def read_only
    true
  end

  # Returns true: forces this DP type to be read-only.
  def read_only? #:nodoc:
    true
  end

  # Returns the real path on the DP, since there is no caching here.
  # Note that in the superclass, provider_full_path() will
  # call cache_full_path().
  def cache_full_path(userfile)
    basename    = userfile.name
    browse_path = userfile.browse_path.presence || '.'
    Pathname.new(remote_dir) + browse_path + basename
  end

  # This overrides the superclass method and allows
  # 'going into' subfolders. This DP class doesn't care
  # about user.
  def browse_remote_dir(user, browse_path)
    Pathname.new(remote_dir) + (browse_path ? browse_path : "") # does not care about user
  end

end

