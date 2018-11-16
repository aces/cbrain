
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

# This file contains miscellaneous console shortcuts for
# administrators or advanced developers.

# Turns online a resource that has a 'online' attribute.
# Saves it immediately.
def online(*args) #:nodoc:
  args.flatten.map do |obj|
    if obj.respond_to?("online=")
      obj.update_column(:online, true)
    else
      puts "==== Object does not respond to online(): #{obj.inspect} ===="
    end
  end
end

# Turns offline a resource that has a 'online' attribute.
# Saves it immediately.
def offline(*args) #:nodoc:
  args.flatten.map do |obj|
    if obj.respond_to?("online=")
      obj.update_column(:online, false)
    else
      puts "==== Object does not respond to online(): #{obj.inspect} ===="
    end
  end
end

(CbrainConsoleFeatures ||= []) << <<FEATURES
========================================================
Feature: admin shortcuts
========================================================
  online  something  # turns it online immediately (writes to DB)
  offline something  # turns it offline immediately (writes to DB)
FEATURES
