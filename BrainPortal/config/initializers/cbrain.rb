
#
# CBRAIN Project
#
# CBRAIN configuration values common to both BrainPortal and Bourreau
#
# Original author: Pierre Rioux
#
# $Id$
#

require 'cbrain_exception'

require 'yaml'
require 'psych'
YAML::ENGINE.yamler = 'psych'

# CBRAIN constants and some global utility methods.
class CBRAIN

  Revision_info=CbrainFileRevision[__FILE__]

  public

  Startup_LocalTime  = Time.now.localtime
  Rails_UserId       = Process.uid
  Rails_UserName     = Etc.getpwuid(Rails_UserId).name
  Rails_UserHome     = Etc.getpwuid(Rails_UserId).dir
  System_Uname       = `uname -a`.chomp
  ENV['PATH']        = "#{Rails.root.to_s}/vendor/cbrain/bin:#{ENV['PATH']}"

  # CBRAIN plugins locations
  Plugins_Dir          = "#{Rails.root.to_s}/cbrain_plugins"
  TasksPlugins_Dir     = "#{Plugins_Dir}/cbrain_task" # singular; historical
  UserfilesPlugins_Dir = "#{Plugins_Dir}/userfiles"

  $CBRAIN_StartTime_Revision = "???"  # numeric; will be filled in by validation script

  # Some environment variables MUST be set for some subsystems to work.
  # In deployment at McGill, we run the rails application under control
  # of 'monit' which clears the environment of almost everything!
  ENV['HOME'] = Rails_UserHome        # Most notably, ssh and Net::SFTP needs this

  # File creation umask
  File.umask(0027)  # octal literal

  # Run the associated block as a background process to avoid
  # blocking.
  #
  # Most of the code in this method comes from a blog entry
  # by {Scott Persinger}[http://geekblog.vodpod.com/?p=26].
  #
  # In case of an untrapped exception being raised in the background code,
  # a CBRAIN Message will be sent to +destination+ (which can be a Group,
  # a User, a Site, or the keywords :nobody or :admin) with +taskname+ being
  # reported in the header of the Message.
  #
  # This method won't work if used inside the RAILS initialization
  # code in 'config/initializers'.
  def self.spawn_with_active_records(destination = nil, taskname = 'Internal Background Task')
    dbconfig = ActiveRecord::Base.remove_connection
    reader,writer = IO.pipe  # The stream that we use to send the subchild's pid to the parent
    childpid = Kernel.fork do

      # Child code starts here
      reader.close # Not needed in the child!

      # Create subchild
      subchildpid = Kernel.fork do

        # Subchild code starts here
        writer.close # Not needed in the subchild!

        # Background code execution
        begin
          $0 = "#{taskname}" # Clever!
          Process.setpgrp rescue true
          ActiveRecord::Base.establish_connection(dbconfig)
          yield

        # Background untrapped exception handling
        rescue ActiveRecord::StatementInvalid, Mysql::Error => e
          puts "#{taskname} PID #{Process.pid}: Oh oh. The DB connection was closed! Nothing to do but exit!"
        rescue Exception => itswrong
          destination = User.find_by_login('admin') if destination.blank? || destination == :admin
          Message.send_internal_error_message(destination,taskname,itswrong) unless destination == :nobody
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
  
  # This method runs a Ruby block in the background, as a separate subprocess,
  # but without any access to the services provided by Rails (no ActiveRecords,
  # no DB, all filehandles closed except for STDIN, STDOUT and STDERR). If
  # an exception is raised, a message is printed in STDOUT and the subprocess
  # exits.
  def self.spawn_fully_independent(taskname = 'Independent Background Task')
    reader,writer = IO.pipe  # The stream that we use to send the subchild's pid to the parent
    childpid = Kernel.fork do

      # Child code starts here
      reader.close # Not needed in the child!

      # Create subchild
      subchildpid = Kernel.fork do

        # Try to close all file descriptors from 3 to 50.
        writer.close # Not needed in the subchild!
        (3..50).each { |i| IO.for_fd(i).close rescue true } # with some luck, it's enough

        # Background code execution
        begin
          $0 = "#{taskname}" # Clever!
          Process.setpgrp rescue true
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

