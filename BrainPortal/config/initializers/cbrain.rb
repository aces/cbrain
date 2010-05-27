
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

# CBRAIN constants and some global utility methods.
class CBRAIN

  Revision_info="$Id$"
  Redmine_Version="1.3.0"

  public

  Startup_LocalTime = Time.now.localtime
  Rails_UserId      = Process.uid
  Rails_UserName    = Etc.getpwuid(Rails_UserId).name
  Rails_UserHome    = Etc.getpwuid(Rails_UserId).dir
  System_Uname      = `uname -a`.chomp

  # This value is used to trigger DP cache wipes
  # in the validation code (see PortalSystemChecks)
  # Instructions: when the caching system changes,
  # increase this numebr to the highest SVN rev
  # BEFORE the commit that implements the change,
  # then commit this file with the new caching system.
  # It's important that this value be less than
  # the rev of new data_provider.rb.
  DataProviderCache_RevNeeded = 959

  # Some environment variables MUST be set for some subsystems to work.
  # In deployment at McGill, we run the rails application under control
  # of 'monit' which clears the environment of almost everything!
  ENV['HOME'] = Rails_UserHome        # Most notably, Net::SFTP needs this

  # File creation umask
  File.umask(0027)  # octal literal

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

      # Create subchild
      subchildpid = Kernel.fork do

        # Subchild code starts here
        writer.close # Not needed in the subchild!

        # Background code execution
        begin
          $0 = "#{taskname}" # Clever!
          # Monkey-patch Mongrel to not remove its pid file in the child
          Mongrel::Configurator.class_eval("def remove_pid_file; true; end")
          ActiveRecord::Base.establish_connection(dbconfig)
          yield

        # Background untrapped exception handling
        rescue ActiveRecord::StatementInvalid => e
          puts "#{taskname} PID #{Process.pid}: Oh oh. The DB connection was closed! Nothing to do but exit!"
        rescue Exception => itswrong
          unless destination
            destination = User.find_by_login('admin')
            taskname += " (No Destination Provided!)"
          end
          Message.send_internal_error_message(destination,taskname,itswrong)
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

  # This method is just like spawn_with_active_records() except
  # that the block will be spawn only when +condition+ is
  # true; otherwise the block is executed in the current process.
  #
  # This is useful on the portal side when you have a block of
  # instructions where in some circumstances you want it spawned
  # and in others you want to wait until it's finished.
  def self.spawn_with_active_records_if(condition,destination = nil, taskname = 'Internal Background Task')
    if condition
      self.spawn_with_active_records(destination,taskname) { yield }
    else
      begin
        yield
      rescue => itswrong
        Message.send_internal_error_message(destination,"#{taskname} with PID #{Process.pid}",itswrong)
      end
    end
  end
  
  # This method is just like spawn_with_active_records() except
  # that the block will be spawn only when +condition+ is
  # false; otherwise the block is executed in the current process.
  #
  # This is useful on the portal side when you have a block of
  # instructions where in some circumstances you want it spawned
  # and in others you want to wait until it's finished.
  def self.spawn_with_active_records_unless(condition,destination = nil, taskname = 'Internal Background Task', &block)
    self.spawn_with_active_records_if(!condition,destination, taskname, &block)
  end

  # This method runs a Ruby block in the background, as a separate subprocess,
  # but without any access to the services provided by Rails (no ActiveRecords,
  # no DB, all filehandles closed except for STDIN, STDOUT and STDERR). If
  # an exception is raised, a message is printed in STDOUT and the subprocess
  # exits.
  def self.spawn_fully_independent(taskname = 'Independent Background Task')
    reader,writer = IO.pipe  # The stream that we use to send the subchild's pid to the parent
    childpid = Kernel.fork do

      # Child code starts here
      Mongrel::HttpServer.cbrain_force_close_server_socket # special to CBRAIN
      reader.close # Not needed in the child!

      # Create subchild
      subchildpid = Kernel.fork do

        # Try to close all file descriptors from 3 to 50.
        writer.close # Not needed in the subchild!
        begin
          (3..50).each { |i| x = IO.for_fd(i) rescue nil ; x.close if x }
        rescue
        end

        # Background code execution
        begin
          $0 = "#{taskname}" # Clever!
          yield
        rescue => itswrong
          puts "Exception raised in spawn_fully_independent():\n"
          puts itswrong.class.to_s + ": " + itswrong.message
          puts itswrong.backtrace.join("\n")
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
    subchildpid
  end

end  # End of CBRAIN class



#
# Kernel extensions
#

module Kernel

  # Raises a CbrainNotice exception, with a default redirect to
  # the current controller's index action.
  def cb_notify(message = "Something may have gone awry.", redirect = nil )
    raise CbrainNotice.new(message, redirect)
  end
  alias cb_notice cb_notify

  # Raises a CbrainError exception, with a default redirect to
  # the current controller's index action.
  def cb_error(message = "Some error occured.",  redirect = nil )
    raise CbrainError.new(message, redirect)
  end

end


#
# CBRAIN patches to Mongrel.
#

module Mongrel

  #
  # CBRAIN patches to its HTTP Server.
  #
  # These patches are mostly required by the CBRAIN methods
  # spawn_with_active_records(), spawn_with_active_records_if()
  # and spawn_fully_independent().
  #
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

#
# Extensions to core types
#

class Symbol

  # Used by views for CbrainTasks to transform a
  # symbol sych as :abc into a path to a variable
  # inside the params[] hash, as "cbrain_task[params][abc]".
  def to_la
    "cbrain_task[params][#{self}]"
  end

end

class String

  # Used by views for CbrainTasks to transform a
  # string sych as "abc" or "abc[def]" into a path to a
  # variable inside the params[] hash, as in
  # "cbrain_task[params][abc]" or "cbrain_task[params][abc][def]"
  def to_la
    key = self
    if key =~ /^(\w+)/
      newcomp = "[" + Regexp.last_match[1] + "]"
      key.sub!(/^(\w+)/,newcomp)
    end
    "cbrain_task[params]#{key}"
  end

end
