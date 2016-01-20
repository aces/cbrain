
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

require 'socket'

CbrainSystemChecks.print_intro_info # general information printed to STDOUT

# Checking to see if this command requires validation or not

program_name = $PROGRAM_NAME || $0
program_name = Pathname.new(program_name).basename.to_s if program_name
first_arg    = ARGV[0]
rails_command = $LOADED_FEATURES.detect { |path| path =~ /rails\/commands\/\w+\.rb$/ }
program_name = Pathname.new(rails_command).basename(".rb").to_s if rails_command

#puts_cyan "Program=#{program_name} ARGV=(#{ARGV.join(" | ")})"

if program_name == 'rake' # script/generate or script/destroy
  puts "C> \t- Running Rake '#{first_arg}'."
else
  if ENV['CBRAIN_SKIP_VALIDATIONS']
    puts "C> \t- Warning: environment variable 'CBRAIN_SKIP_VALIDATIONS' is set, so we\n"
    puts "C> \t-          are skipping all validations! Proceed at your own risks!\n"
  else
    if program_name =~ /console/
      puts "C> \t- Note:  You can skip all CBRAIN validations by temporarily setting the\n"
      puts "C> \t         environment variable 'CBRAIN_SKIP_VALIDATIONS' to '1'.\n"
      CbrainSystemChecks.check(:all)
      BourreauSystemChecks.check([
        :a050_ensure_proper_cluster_management_layer_is_loaded, :z000_ensure_we_have_a_forwarded_ssh_agent,
      ])
      $0 = "Rails Console #{RemoteResource.current_resource.class} #{RemoteResource.current_resource.name} #{CBRAIN::Instance_Name}\0"
    else # normal server mode
      CbrainSystemChecks.check(:all)
      BourreauSystemChecks.check(:all)
      $0 = "Rails Server #{RemoteResource.current_resource.class} #{RemoteResource.current_resource.name} #{CBRAIN::Instance_Name}\0"
    end
  end
end

#-----------------------------------------------------------------------------
puts "C> CBRAIN Bourreau validation completed, " + Time.now.to_s
#-----------------------------------------------------------------------------

