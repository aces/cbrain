
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
if ARGV[0] == "db:sanity:check" or ARGV[0] == "db:migrate" or ARGV[0] == "migration"
  #------------------------------------------------------------------------------
  puts "C> \t- No validations needed. Skipping."
  #------------------------------------------------------------------------------
elsif ARGV[0].nil? #There might be no argument like when doing script/server or thin start
  PortalSystemCheck.check(:all)
elsif  ARGV[0].include? "spec" #if running the test suite, make model sane and run the validation
  PortalSanityCheck.check(:all)
  PortalSystemCheck.check(PortalSystemCheck.all - [:check_database_sanity])
else
  PortalSystemCheck.check(:all)
end

