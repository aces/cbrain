
#
# CBRAIN Project
#
# Main CBRAIN-specific configuration file
#
# Original author: Pierre Rioux
#
# $Id$
#

class CBRAIN

    Revision_info="$Id$"

    public

    def self.filevault_dir  # TODO make it change with dev/prod/test env ?!?
        "vault"
    end

    def self.filemanager_resource_url
        "http://localhost:3000/"
    end

    unless File.directory?(self.filevault_dir)
        raise "CBRAIN configuration error: file vault #{self.filevault_dir} does not exist!"
    end

end
