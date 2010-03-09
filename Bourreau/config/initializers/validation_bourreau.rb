
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
BourreauSystemChecks.check(:all)


#-----------------------------------------------------------------------------
puts "C> Informing outside world that validations have passed..."
#-----------------------------------------------------------------------------

# The CBRAIN_SERVER_STATUS_FILE environment variable is set up in the
# CBRAIN wrapper script 'cbrain_remote_ctl'. If it's not set we do not do
# anything. It's used by the wrapper to figure out if we launched properly.
server_status_file = ENV["CBRAIN_SERVER_STATUS_FILE"]
if ! server_status_file.blank?
  File.open(server_status_file,"w") do |fh|
    fh.write "STARTED\n"
  end
end
