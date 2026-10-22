
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

# This subclass of CbrainTask provides the methods and developer API
# for deploying CbrainTasks on the BrainPortal side.
class PortalTask < CbrainTask

  if Rails.app_class.to_s == "CbrainRailsPortal::Application"

    include PortalTaskBehaviors

  elsif Rails.app_class.to_s == "CbrainRailsBourreau::Application"

    include ClusterTaskBehaviors

  else

    raise "Configuration error: this Rails app is neither a CbrainRailsPortal::Application or a CbrainRailsBourreau::Application"
  end

end
