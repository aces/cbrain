
#
# CBRAIN Project
#
# CBRAIN configuration values common to both BrainPortal and Bourreau
#
# Original author: Pierre Rioux
#
# $Id$
#

class CBRAIN
    
  public

  # Utility constants
  Startup_LocalTime = Time.now.localtime
  Rails_UserId      = Process.uid
  Rails_UserName    = Etc.getpwuid(Rails_UserId).name
  Rails_UserHome    = Etc.getpwuid(Rails_UserId).dir

  # Some environment variables MUST be set for some subsystems to work.
  # In deployment at McGill, we run the rails application under control
  # of 'monit' which clears the environment of almost everything!
  ENV['HOME'] = Rails_UserHome        # Most notably, Net::SFTP needs this

end

#
# Mongrel and Rails code patches
#

require 'mongrel'

module Mongrel
  class HttpServer

    alias original_configure_socket_options configure_socket_options

    # This is a patch to Mongrel::HttpServer to make sure
    # that Mongrel's internal listen socket is configured
    # with the close-on-exec flag.
    def configure_socket_options
      @socket.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC) rescue true
      original_configure_socket_options
    end
  
  end
end
