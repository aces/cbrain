
#
# CBRAIN Project
#
# CBRAIN configuration values common to both BrainPortal and Bourreau
#
# Original author: Pierre Rioux
#
# $Id$
#

require 'mongrel'
require 'cbrain_exception'

class CBRAIN

  Revision_info="$Id$"
  Redmine_Version="1.1.8"

  public

  # Utility constants
  Startup_LocalTime = Time.now.localtime
  Rails_UserId      = Process.uid
  Rails_UserName    = Etc.getpwuid(Rails_UserId).name
  Rails_UserHome    = Etc.getpwuid(Rails_UserId).dir
  System_Uname      = `uname -a`.chomp

  # Some environment variables MUST be set for some subsystems to work.
  # In deployment at McGill, we run the rails application under control
  # of 'monit' which clears the environment of almost everything!
  ENV['HOME'] = Rails_UserHome        # Most notably, Net::SFTP needs this

  # Run the associated block as a background process to avoid
  # blocking.
  #
  # Most of the code in this method comes from a blog entry
  # by {Scott Persinger}[http://geekblog.vodpod.com/?p=26].
  #
  # The forking code has been modified to call a special
  # CBRAIN patch to Mongrel to make sure its sockets
  # are closed.
  #
  # In case of an untrapped exception being raised in the background code,
  # a CBRAIN Message will be sent to +destination+ (which can be a Group,
  # a User, or a Site) with +taskname+ being reported in the header of
  # the Message.
  #
  # This method won't work if used inside the RAILS initialization
  # code in 'config/initializers'.
  def self.spawn_with_active_records(destination = nil, taskname = 'Internal Background Task')
    dbconfig = ActiveRecord::Base.remove_connection
    reader,writer = IO.pipe  # The stream that we use to send the subchild's pid to the parent
    childpid = Kernel.fork do

      # Child code starts here
      Mongrel::HttpServer.cbrain_force_close_server_socket # special to CBRAIN
      reader.close # Not needed in the child!
      subchildpid = Kernel.fork do

        # Subchild code starts here
        writer.close # Not needed in the subchild!

        # Background code execution
        begin
          # Monkey-patch Mongrel to not remove its pid file in the child
          Mongrel::Configurator.class_eval("def remove_pid_file; true; end")
          ActiveRecord::Base.establish_connection(dbconfig)
          yield

        # Background untrapped exception handling
        rescue ActiveRecord::StatementInvalid => e
          puts "#{taskname} PID #{$$}: Oh oh. The DB connection was closed! Nothing to do but exit!"
        rescue Exception => itswrong
          unless destination
            destination = User.find_by_login('admin')
            taskname += " (No Destination Provided!)"
          end
          messtype = 'error'
          messtype = 'notice' if itswrong.is_a? CbrainNotice # TODO handle CbrainError too?

          Message.send_message(destination, messtype,
            # Header
            "Background Error: '#{taskname}'",                            
  
            # Description
            "An internal error occured in a background task.\n"       +   
            "Please let the CBRAIN development team know about it,\n" +
            "as this is not supposed to go unchecked.\n"              +
            "The last 15 caller entries are in attachement.\n",
  
            # Var text
            "#{itswrong.class.to_s}: #{itswrong.message}\n" +   
            itswrong.backtrace[0..15].join("\n") + "\n"
          )
        ensure
          ActiveRecord::Base.remove_connection
          Kernel.exit! # End of subchild.
        end
        Kernel.exit! # End of subchild.
      end

      # Child code continues here
      Process.detach(subchildpid)
      writer.write(subchildpid.to_s)
      writer.close # Child is done sending the subchild's PID to parent
      Kernel.exit! # End of child.
    end

    # Parent code continues here
    Process.detach(childpid)
    writer.close # Not needed in parent!
    subchildpid = reader.read.to_i
    reader.close # Parent is done reading subchild's PID from child
    ActiveRecord::Base.establish_connection(dbconfig)
    subchildpid
  end

  def self.spawn_fully_independent
    pid = Process.fork do  # TODO fork two levels too ?
      Mongrel::HttpServer.cbrain_force_close_server_socket # special to CBRAIN
      # Try to close all file descriptions from 3 to 50.
      begin
        (3..50).each { |i| x = IO.for_fd(i) rescue nil ; x.close if x }
      rescue
      end
      # Try executing the code
      begin
        yield
      rescue
      end
      # End it all.
      Kernel.exit!
    end
    Process.detach(subpid)
    pid
  end

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
