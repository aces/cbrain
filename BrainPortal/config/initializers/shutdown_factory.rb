
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

# This initializer creates a hook called when the Rails application exits.
# A more generic way to do that would be to create a "finalizers" directory to contain all the scripts to be called when Rails exits.
# But there doesn't seem to be any other case for running a script at exit. So I leave it like this for now. 
# See discussion on http://stackoverflow.com/questions/5545000/how-to-launch-a-thread-at-the-start-of-a-rails-app-and-terminate-it-at-stop

at_exit do
  VmFactory.stop_all
end
