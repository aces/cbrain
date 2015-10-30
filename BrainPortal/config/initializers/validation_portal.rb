
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

#=================================================================
# IMPORTANT NOTE : When adding new validation code in this file,
# remember that in deployment there can be several instances of
# the Rails application all executing this code at the same time.
#=================================================================

require 'socket'

#-----------------------------------------------------------------------------
puts "C> CBRAIN BrainPortal validation starting, " + Time.now.to_s
puts "C> Rails environment is set to '#{Rails.env}'"
puts "C> RAILS_ENV variable is set to '#{ENV['RAILS_ENV']}'" if (! ENV['RAILS_ENV'].blank?) && (Rails.env != ENV['RAILS_ENV'])
puts "C> CBRAIN instance is named '#{CBRAIN::Instance_Name}'"
puts "C> Hostname is '#{Socket.gethostname rescue "(Exception)"}'"
#-----------------------------------------------------------------------------

# Checking to see if this command requires validation or not

program_name = $PROGRAM_NAME || $0
program_name = Pathname.new(program_name).basename.to_s if program_name
first_arg    = ARGV[0]
rails_command = $LOADED_FEATURES.detect { |path| path =~ /rails\/commands\/\w+\.rb$/ }
program_name = Pathname.new(rails_command).basename(".rb").to_s if rails_command

#puts_cyan "Program=#{program_name} ARGV=(#{ARGV.join(" | ")})"
#puts_cyan "FirstArg=#{first_arg} RailsCommand=#{rails_command}"

#
# Exceptions By Program Name
#

if program_name =~ /console/ # console or dbconsole
  if ENV['CBRAIN_SKIP_VALIDATIONS']
    puts "C> \t- Warning: environment variable 'CBRAIN_SKIP_VALIDATIONS' is set, so we\n"
    puts "C> \t-          are skipping all validations! Proceed at your own risks!\n"
    CbrainSystemChecks.check([:a002_ensure_Rails_can_find_itself]) rescue true
  else
    puts "C> \t- Note:  You can skip all CBRAIN validations by temporarily setting the\n"
    puts "C> \t         environment variable 'CBRAIN_SKIP_VALIDATIONS' to '1'.\n"
    CbrainSystemChecks.check(:all)
    PortalSystemChecks.check(:all)
  end
  $0 = "Rails Console #{RemoteResource.current_resource.class} #{RemoteResource.current_resource.name} #{CBRAIN::Instance_Name}\0"
elsif program_name == "rails" # probably 'generate', 'destroy', 'plugin' etc, but we can't tell!
  puts "C> \t- Running Rails utility."
elsif program_name == 'rspec' # test suite
  puts "C> \t- Testing with 'rspec'."
  CbrainSystemChecks.check([:a002_ensure_Rails_can_find_itself])
elsif program_name == "rake"
  #
  # Rake Exceptions By First Argument
  #
  skip_validations_for = [ /^db:/, /^cbrain:plugins/, /^route/ ]
  if skip_validations_for.any? { |p| first_arg =~ p }
    #------------------------------------------------------------------------------
    puts "C> \t- No validations needed. Skipping."
    #------------------------------------------------------------------------------
  elsif ! first_arg.nil? && first_arg.include?("spec") #if running the test suite, make model sane and run the validation
    PortalSanityChecks.check(:all)
    CbrainSystemChecks.check(:all)
    PortalSystemChecks.check(PortalSystemChecks.all - [:a020_check_database_sanity])
  else # all other rake cases
    CbrainSystemChecks.check(:all)
    PortalSystemChecks.check(:all)
  end
else # all other cases
  CbrainSystemChecks.check(:all)
  PortalSystemChecks.check(:all)
  $0 = "Rails Server #{RemoteResource.current_resource.class} #{RemoteResource.current_resource.name} #{CBRAIN::Instance_Name}\0"
end

#-----------------------------------------------------------------------------
puts "C> CBRAIN BrainPortal validation completed, " + Time.now.to_s
#-----------------------------------------------------------------------------

