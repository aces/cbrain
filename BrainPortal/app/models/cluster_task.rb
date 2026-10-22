
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

# There used to be two 'branches' in the class hierarchy
# under CbrainTask, one going through PortalTask and one going through ClusterTask.
# For the V8 release of CBRAIN, this clumsy system was simplified
# as a straight linear set of classes. So the definition of
# ClusterTask is simply to point it to PortalTask.
#
# Note that within the definition of PortalTask, we include distinct
# modules to somehow recreate the original situation. See the code there.
ClusterTask = PortalTask

