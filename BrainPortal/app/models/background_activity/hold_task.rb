
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

# Holds a CBRAIN task. This is the cluster operation of
# holding a job currently Queued
#
# This is part of a set of four cluster operations
# that, within CBRAIN, have no supporting interface elements
# or API calls:
#
#   suspend, resume, hold, release
#
# This is implemented for the sake of completing the official
# CBRAIN low-level job control features.
class BackgroundActivity::HoldTask < BackgroundActivity

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  before_save :must_be_on_bourreau!

  def process(item)
    task  = CbrainTask.where(:bourreau_id => CBRAIN::SelfRemoteResourceId).find(item)
    ok    = task.hold
    task.addlog("New status: #{task.status}") if ok
    return [ true,  "Resumed" ] if   ok
    return [ false, "Skipped" ] if ! ok
  end

end

