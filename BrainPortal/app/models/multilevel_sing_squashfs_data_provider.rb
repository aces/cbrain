
#
# CBRAIN Project
#
# Copyright (C) 2008-2025
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

# This class implements the same kind of provider
# as SingSquashfsDataProvider, but with browse_path support.
class MultilevelSingSquashfsDataProvider < SingSquashfsDataProvider

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def has_browse_path_capabilities?
    true
  end

  # This returns the category of the data provider
  def self.pretty_category_name #:nodoc:
    "Multi Level"
  end

  def provider_full_path(userfile)
    # It's amazing what object-oriented programming can do sometimes.
    #Pathname.new(self.containerized_path) + userfile.name # old code in parent class
    Pathname.new(self.containerized_path) + userfile.browse_name # just add the intermediate folders
  end

end
