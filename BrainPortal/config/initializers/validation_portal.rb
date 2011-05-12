
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

# Checking to see if this command requires validation or not

program_name = $PROGRAM_NAME || $0    # script/console will set it to 'irb'
first_arg    = ARGV[0]

#
# Exceptions By Program Name
#

if program_name == 'irb' # for script/console
  if ENV['CBRAIN_SKIP_VALIDATIONS']
    puts "C> \t- Warning: environment variable 'CBRAIN_SKIP_VALIDATIONS' is set, so we\n"
    puts "C> \t-          are skipping all validations! Proceed at your own risks!\n"
  else
    puts "C> \t- Note:  You can skip all CBRAIN validations by temporarily setting the\n"
    puts "C> \t         environment variable 'CBRAIN_SKIP_VALIDATIONS' to '1'.\n"
    CbrainSystemChecks.check(:all)
    PortalSystemChecks.check(:all)
  end
elsif program_name =~ /about$/ # script/about
  puts "C> \t- What's this all ABOUT?"
elsif program_name =~ /generate$|destroy$/ # script/generate or script/destroy
  puts "C> \t- Running Rails utility '#{program_name}'."

#
# Exceptions By First Argument
#

elsif first_arg == "db:sanity:check" 
  #------------------------------------------------------------------------------
  puts "C> \t- No more validations needed for sanity checks. Skipping."
  #------------------------------------------------------------------------------
elsif first_arg =~ /db:migrate|db:rollback|migration|db:schema:load/
  #------------------------------------------------------------------------------
  puts "C> \t- No validations needed for DB migrations. Skipping."
  #------------------------------------------------------------------------------
elsif ! first_arg.nil? && first_arg.include?("spec") #if running the test suite, make model sane and run the validation
  PortalSanityChecks.check(:all)
  CbrainSystemChecks.check(:all)
  PortalSystemChecks.check(PortalSystemChecks.all - [:a020_check_database_sanity])
else
  CbrainSystemChecks.check(:all)
  PortalSystemChecks.check(:all)
end

