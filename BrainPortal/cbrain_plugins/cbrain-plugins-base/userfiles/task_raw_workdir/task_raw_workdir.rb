
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

#This model is meant to represent an arbitrary collection files (which
#may or may not contain subdirectories) registered as a single entry in
#the userfiles table.
class TaskRawWorkdir < FileCollection

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  self.pretty_type #:nodoc:
    "Task raw workdir"
  end

end


