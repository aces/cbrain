
#
# CBRAIN Project
#
# Main CBRAIN-specific configuration file
#
# Original author: Pierre Rioux
#
# $Id: cbrain.rb 40 2008-11-03 20:30:49Z tsherif $
#

# CBRAIN deployment constants
# This file is used both by BrainPortal and Bourreau
class CBRAIN

    public

    Revision_info="$Id: cbrain.rb 40 2008-11-03 20:30:49Z tsherif $"

    # BrainPortal constants
    Filevault_dir            = "/Users/Tarek/Code/rails/BrainPortal2/vault"

    # Bourreau constants
    Bourreau_execution_URL   = "http://localhost:2500/"

    # Run-time checks
    unless File.directory?(Filevault_dir) # todo: check only for BrainPortal
        raise "CBRAIN configuration error: file vault #{Filevault_dir} does not exist!"
    end

end