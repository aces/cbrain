
#
# CBRAIN Project
#
# Validation code for Bourreau
#
# Original author: Pierre Rioux
#
# $Id$
#

#-----------------------------------------------------------------------------
puts "C> CBRAIN Bourreau validation starting, " + Time.now.to_s
#-----------------------------------------------------------------------------

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
    end
    CbrainSystemChecks.check(:all)
    BourreauSystemChecks.check(:all)
  end
end

#-----------------------------------------------------------------------------
puts "C> CBRAIN Bourreau validation completed, " + Time.now.to_s
#-----------------------------------------------------------------------------

