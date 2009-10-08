
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

  Revision_info="$Id$"
  Redmine_Version="1.1.8"

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
    alias original_process_client           process_client

    # This is a patch to Mongrel::HttpServer to make sure
    # that Mongrel's internal listen socket is configured
    # with the close-on-exec flag.
    def configure_socket_options
      @socket.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC) rescue true
      @@cbrain_socket = @socket
      original_configure_socket_options
    end

    # This is a patch to Mongrel::HttpServer to make sure
    # that Mongrel's internal listen socket is configured
    # with the close-on-exec flag. We also record the two
    # socket endpoints of the server's HTTP channel, so
    # that we can quickly close them in the patch method
    # cbrain_force_close_server_socket()
    def process_client(client)
      @@cbrain_client_socket ||= {}
      @@cbrain_client_socket[Thread.current.object_id] = client
      original_process_client(client)
      @@cbrain_client_socket.delete(Thread.current.object_id)
    end

    # This CBRAIN patch method allows explicitely to close
    # Mongrel's main acceptor socket (stored in a class variable)
    # and the client's socket (stored in a class hash, by thread).
    def self.cbrain_force_close_server_socket
      begin
        @@cbrain_socket.close                                  rescue true
        @@cbrain_client_socket[Thread.current.object_id].close rescue true
      rescue
      end
    end
  
  end
end
