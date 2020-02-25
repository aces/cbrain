
#
# NeuroHub Project
#
# Copyright (C) 2020
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

# Helper for Neurohub interface
module NeurohubHelpers

  # For the user +user+, this method will return a proper
  # neurohub project (class WorkGroup) associated with +id_or_project+.
  # If +id_or_project_ is already a Group, it will make sure it's
  # a valid one. The WorkGroup is returned. If the validation fails,
  # an exception ActiveRecord::RecordNotFound is raised.
  def find_nh_project(user, id_or_project)
    id      = id_or_project.is_a?(Group) ? id_or_project.id : id_or_project
    project = user.available_groups.where(:type => "WorkGroup").find(id)

    raise ActiveRecord::RecordNotFound unless project.can_be_accessed_by?(user)

    project
  end

  # For the user +user+, this method will return
  # neurohub projects ('available' groups of class WorkGroup)
  def find_nh_projects(user)
    current_user.available_groups.where(:type => 'WorkGroup')
  end

end
