
#
# CBRAIN Project
#
# Main CBRAIN-specific configuration file
#
# Original author: Pierre Rioux
#
# $Id$
#

# CBRAIN deployment constants
# This file is used both by BrainPortal and Bourreau
class CBRAIN

    public

    Revision_info="$Id$"

    # BrainPortal constants
    Filevault_dir            = "vault"   # relative to mongrel's cwd at startup! todo!

    # FileShuttle constants
    Userfiles_resource_URL   = "http://localhost:3500/"

    # Bourreau constants
    Bourreau_execution_URL   = "http://localhost:2500/"

    # Run-time checks
    unless File.directory?(Filevault_dir) # todo: check only for BrainPortal
        raise "CBRAIN configuration error: file vault #{Filevault_dir} does not exist!"
    end

end
