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


# Tasks submitted to a
# Disk Image don't have any "concrete" Bourreau until one decides to
# execute them. DiskImage needs at least :cbrain_tasks,
# :tool_configs and :tools from class Bourreau. It also needs :user
# and :group from RemoteResource.  Inheriting class Bourreau is not
# really correct, since the methods used for remote controlling don't
# make sense here. This should be discussed with Pierre when a first,
# working version of DiskImage is available.  By the way,
# inheritance of RemoteResource for BrainPortal is a bit weird too:
# for instance, RemoteResource has :cms_class, which doesn't really
# make sense for BrainPortal (same for :workers_instances and all
# other symbols specific to bourreau). Following this, I put symbols
# specific to DiskImage in RemoteResources too...

class DiskImage < Bourreau
  def start
    cb_error "This should launch StartVM"
  end

  def type_string
    return "Disk Image"
  end
end
