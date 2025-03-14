
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

def plog(*args)
  no_log do
    to_show = args.flatten
    to_show.each do |obj|
      if obj.respond_to?(:getlog)
        log = obj.getlog rescue "(Exception getting log)"
        puts "==== Log for #{obj.inspect} ====" if to_show.size > 1
        puts log.to_s
      else
        puts "==== Object does not respond to getlog(): #{obj.inspect} ===="
      end
    end
  end
  true
end

(CbrainConsoleFeatures ||= []) << <<FEATURES
========================================================
Feature: print ActiveRecordLog of some objects
========================================================
  plog obj [, obj , ...]

  If an object has an internal log, shows that log.
FEATURES

