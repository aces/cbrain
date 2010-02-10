
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
if ARGV[0] == "db:sanity:check" 
  PortalSystemCheck.check([:a003_check_configuration_variables])
  #------------------------------------------------------------------------------
  puts "C> \t- No more validations needed. Skipping."
  #------------------------------------------------------------------------------
elsif ARGV[0] == "db:migrate" or ARGV[0] == "migration" or ARGV[0] == "db:schema:load"
  #------------------------------------------------------------------------------
  puts "C> \t- No validations needed. Skipping."
  #------------------------------------------------------------------------------
elsif ARGV[0].nil? #There might be no argument like when doing script/server or thin start
  PortalSystemCheck.check(:all)
elsif  ARGV[0].include? "spec" #if running the test suite, make model sane and run the validation
  PortalSystemCheck.check([:a003_check_configuration_variables])
  PortalSanityCheck.check(:all)
  PortalSystemCheck.check(PortalSystemCheck.all - [:a002_check_database_sanity, :a003_check_configuration_variables])
else
  PortalSystemCheck.check(:all)
end

