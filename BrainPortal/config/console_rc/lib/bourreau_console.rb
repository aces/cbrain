
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

# Adds two wrapper commands to connect to the Rails Console
# of remote Bourreaux:
#
# bourreau.console  # connects to the console of object 'bourreau'
# Bourreau.console(id_or_name_or_regex) # finds a bourreau and connects
Bourreau.nil? # does nothing but loads the class
class Bourreau

  def console #:nodoc:
    start_remote_console
  end

  def self.console(id) #:nodoc:
    b   = self.find(id)         rescue nil
    b ||= self.find_by_name(id) rescue nil
    b ||= self.all.detect { |x| x.name =~ id } if id.is_a?(Regexp)
    unless b
      puts "Can't find a Bourreau that match '#{id.inspect}'"
      return
    end
    puts "Starting console for Bourreau '#{b.name}'"
    b.console
  end
end

(CbrainConsoleFeatures ||= []) << <<FEATURES
========================================================
Feature: invoking a console on a bourreau, for debugging
========================================================
  bourreau.console     # if bourreau is a Bourreau object
  Bourreau.console(id) # if you have th ID

  Note: do not connect from the same terminal that started
  the bourreau with 'ibc', the pseudo-ttys get confused.
  Start another rails console in another terminal if needed.
FEATURES
