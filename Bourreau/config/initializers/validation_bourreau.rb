
#
# CBRAIN Project
#
# Validation code for Bourreau
#
# Original author: Pierre Rioux
#
# $Id$
#

require 'lib/bourreau_system_checks.rb'

#-----------------------------------------------------------------------------
puts "C> CBRAIN Bourreau validation starting, " + Time.now.to_s
#-----------------------------------------------------------------------------

# Checking to see if this command requires validation or not

program_name = $PROGRAM_NAME || $0    # script/console will set it to 'irb'
first_arg    = ARGV[0]

if program_name =~ /about$/ # script/about
  puts "C> \t- What's this all ABOUT?"
elsif program_name =~ /generate$|destroy$/ # script/generate or script/destroy
  puts "C> \t- Running Rails utility '#{program_name}'."
else
  BourreauSystemChecks.check(:all)
end



# The CBRAIN_SERVER_STATUS_FILE environment variable is set up in the
# CBRAIN wrapper script 'cbrain_remote_ctl'. If it's not set we do not do
# anything. It's used by the wrapper to figure out if we launched properly.
server_status_file = ENV["CBRAIN_SERVER_STATUS_FILE"]
if ! server_status_file.blank?

  #-----------------------------------------------------------------------------
  puts "C> Informing outside world that validations have passed..."
  #-----------------------------------------------------------------------------

  File.open(server_status_file,"w") do |fh|
    fh.write "STARTED\n"
  end
end

