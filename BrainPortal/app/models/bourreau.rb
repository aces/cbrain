
#
# CBRAIN Project
#
# Original author: Pierre Rioux
#
# $Id$
#

class Bourreau < RemoteResource

  Revision_info="$Id$"

  def is_alive?
    true; # TODO check for real
  end

  def site
    "http://" + remote_host + (remote_port && remote_port > 0 ? ":#{remote_port}" : "") + remote_dir
  end

end
