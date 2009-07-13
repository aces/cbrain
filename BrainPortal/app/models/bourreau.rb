
#
# CBRAIN Project
#
# Original author: Pierre Rioux
#
# $Id$
#


#This model represents a remote execution server.
class Bourreau < RemoteResource

  Revision_info="$Id$"

  #Checks if this Bourreau is available or not.
  def is_alive?
    true; # TODO check for real
  end

  #Returns this Bourreau's url.
  def site
    "http://" + remote_host + (remote_port && remote_port > 0 ? ":#{remote_port}" : "") + remote_dir
  end

end
