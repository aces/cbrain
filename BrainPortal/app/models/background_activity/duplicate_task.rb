
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

# Duplicate a CBRAIN task.
# The options hash should contain dup_bourreau_id,
# otherwise duplication will occur on the same Bourreau
# as the tasks.
class BackgroundActivity::DuplicateTask < BackgroundActivity

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def pretty_name
    dest_name = RemoteResource.where(:id => self.options[:dub_bourreau_id]).first&.name.presence
    [super, dest_name].compact.join(" to ")
  end

  def process(item)
    task         = CbrainTask.real_tasks.find(item)
    new_bid      = options[:dup_bourreau_id].presence || task.bourreau_id
    new_bourreau = Bourreau.find(new_bid)
    ok           = task.duplicate!(new_bourreau)
    return [ true,  nil          ] if   ok
    return [ false, "Skipped"    ] if ! ok
  end

end

