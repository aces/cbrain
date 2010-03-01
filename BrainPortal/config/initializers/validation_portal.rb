
#
# CBRAIN Project
#
# Validation code for brainportal
#
# Original author: Pierre Rioux
#
# $Id$
#

#=================================================================
# IMPORTANT NOTE : When adding new validation code in this file,
# remember that in deployment there can be several instances of
# the Rails application all executing this code at the same time.
#=================================================================

#-----------------------------------------------------------------------------
puts "C> CBRAIN BrainPortal validation starting, " + Time.now.to_s
#-----------------------------------------------------------------------------

require 'socket'

require 'lib/portal_sanity_checks.rb'
require 'lib/portal_system_checks.rb'


# Checking to see if this command requires the validation or not

program_name = $PROGRAM_NAME || $0    # script/console will set it to 'irb'
first_arg    = ARGV[0]
if first_arg == "db:sanity:check" 
  PortalSystemCheck.check([:a030_check_configuration_variables])
  #------------------------------------------------------------------------------
  puts "C> \t- No more validations needed. Skipping."
  #------------------------------------------------------------------------------
elsif first_arg == "db:migrate" or first_arg == "migration" or first_arg == "db:schema:load"
  #------------------------------------------------------------------------------
  puts "C> \t- No validations needed for DB migrations. Skipping."
  #------------------------------------------------------------------------------
elsif first_arg.nil? #There might be no argument like when doing script/server or thin start
  if program_name == 'irb' # for script/console
    if ENV['CBRAIN_SKIP_VALIDATIONS']
      PortalSystemCheck.check([:a030_check_configuration_variables])
    else
      PortalSystemCheck.check(PortalSystemCheck.all - [:a070_start_bourreau_ssh_tunnels])
    end
  else
    PortalSystemCheck.check(:all) # mostly for script/server
  end
elsif first_arg.include? "spec" #if running the test suite, make model sane and run the validation
  PortalSystemCheck.check([:a030_check_configuration_variables])
  PortalSanityCheck.check(:all)
  PortalSystemCheck.check(PortalSystemCheck.all - [:a020_check_database_sanity, :a030_check_configuration_variables])
else
  PortalSystemCheck.check(:all)
end

