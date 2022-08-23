
#
# CBRAIN Project
#
# Copyright (C) 2008-2022
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

# This class implements the same data provider behavior as
# the S3FlatDataProvider does, except userfiles with a
# browse_path attribute will properly be saved and reloaded
# with that intermediate path inside the S3 key.
#
# E.g. if the DP's root is "data/example", and a
# userfile named "hello.txt" has a browse_path set
# to "local/blah", then the object's name in the bucket
# will be "data/example/local/blah/hello.txt".
class S3MultiLevelDataProvider < S3FlatDataProvider

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def has_browse_path_capabilities? #:nodoc:
    true
  end

end
