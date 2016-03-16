
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

# Rails console initialization code.
puts "C> CBRAIN Rails Console Initalization starting"

# Custom prompt: insert the name of the CBRAIN RemoteResource (portal or Bourreau)
rr_name = RemoteResource.current_resource.name rescue "Rails Console"
IRB.conf[:PROMPT][:CUSTOM] = {
  :PROMPT_I => "#{rr_name} :%03n > ",
  :PROMPT_S => "#{rr_name} :%03n%l> ",
  :PROMPT_C => "#{rr_name} :%03n > ",
  :PROMPT_N => "#{rr_name} :%03n?> ",
  :RETURN   => " => %s \n",
  :AUTO_INDENT => true
}
IRB.conf[:PROMPT_MODE] = :CUSTOM

#####################################################
# Load other console utilities
#####################################################

# Adds "no_log" and "do_log"
require __dir__ + "/lib/logger_rc.rb"

# Adds "bourreau.console" and "Bourreau.console"
require __dir__ + "/lib/bourreau_console.rb"

# Adds "cu", "cp", "current_user" and "current_project"
require __dir__ + "/lib/current_user_project.rb"

# Adds "fff"
require __dir__ + "/lib/fast_finder.rb"

# Adds "ibc"
require __dir__ + "/lib/interactive_bourreau_control.rb"
def ibc ; no_log { InteractiveBourreauControl.new.interactive_control } ; end

# A set of old utilities mostly made obsolete by "ibc" above
require __dir__ + "/lib/old_bourreau_control.rb"

#####################################################
# Load external IRBRC file
#####################################################

IRB.rc_file_generators do |rcgen|
  rc_file_path = rcgen.call("rc")
  if File.exist?(rc_file_path)
    load rc_file_path
    break
  end
end

