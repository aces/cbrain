
#
# CBRAIN Project
#
# Copyright (C) 2022
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

# This class is an intermediate class between BoutiquesPortalTask and
# BoutiquesDescriptorMaker. It provides special functionality
# to allow the interface to dynamically show and render a JSON for
# a boutiques descriptor.
#
# Given that there is no code to actually execute on an Execution
# server, all main framework methods are defined to 'fail'.
# The class still needs to exist to let the Bourreau boot properly.
class BoutiquesDescriptorMakerHandler < BoutiquesClusterTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def setup #:nodoc:
    self.addlog "Impossible code invoked"
    return false # means Failed To Setup
  end

  def cluster_commands #:nodoc:
    self.addlog "Impossible code invoked"
    cb_error "No commands to run"
  end

  def save_results #:nodoc:
    self.addlog "Impossible code invoked"
    return false # means Failed To PostProcess
  end

end

