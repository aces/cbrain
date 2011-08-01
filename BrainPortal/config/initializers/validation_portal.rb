
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

program_name = $PROGRAM_NAME || $0
program_name = Pathname.new(program_name).basename.to_s if program_name
first_arg    = ARGV[0]
rails_command = $LOADED_FEATURES.detect { |path| path =~ /rails\/commands\/\w+\.rb$/ }
program_name = Pathname.new(rails_command).basename(".rb").to_s if rails_command

#puts_cyan "Program=#{program_name} ARGV=(#{ARGV.join(" | ")})"

#
# Exceptions By Program Name
#

if program_name =~ /console/ # console or dbconsole
  if ENV['CBRAIN_SKIP_VALIDATIONS']
    puts "C> \t- Warning: environment variable 'CBRAIN_SKIP_VALIDATIONS' is set, so we\n"
    puts "C> \t-          are skipping all validations! Proceed at your own risks!\n"
  else
    puts "C> \t- Note:  You can skip all CBRAIN validations by temporarily setting the\n"
    puts "C> \t         environment variable 'CBRAIN_SKIP_VALIDATIONS' to '1'.\n"
    CbrainSystemChecks.check(:all)
    PortalSystemChecks.check(:all)
  end
elsif program_name == "rails" # probably 'generate', 'destroy', 'plugin' etc, but we can't tell!
  puts "C> \t- Running Rails utility."
elsif program_name == "rake"
  #
  # Rake Exceptions By First Argument
  #
  if first_arg == "db:sanity:check" 
    #------------------------------------------------------------------------------
    puts "C> \t- No more validations needed for sanity checks. Skipping."
    #------------------------------------------------------------------------------
  elsif first_arg =~ /db:migrate|db:rollback|migration|db:schema/
    #------------------------------------------------------------------------------
    puts "C> \t- No validations needed for DB schema operations. Skipping."
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
end

