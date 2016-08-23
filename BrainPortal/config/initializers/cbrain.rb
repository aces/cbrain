
#
# CBRAIN Project
#
# Copyright (C) 2008-2012
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# CBRAIN constants and some global utility methods.
class CBRAIN

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  public

  Startup_LocalTime  = Time.now.localtime
  Rails_UserId       = Process.uid
  Rails_UserName     = Etc.getpwuid(Rails_UserId).name
  Rails_UserHome     = Etc.getpwuid(Rails_UserId).dir
  System_Uname       = `uname -a`.chomp
  ENV['PATH']        = "#{Rails.root.to_s}/vendor/cbrain/bin:#{ENV['PATH']}"

  # Instance name. An explicit name can be given by setting the environment variable
  # 'CBRAIN_INSTANCE_NAME' before starting the process. Otherwise, we look at the
  # current command line arguments and if we find '-p port', the name is set to
  # 'port'. If all else fails, a string is built like "PID-#{pid}" with the process' PID.
  Instance_Name      = ENV['CBRAIN_INSTANCE_NAME'].presence ||
                       (ARGV.rindex('-p') && ARGV[ARGV.rindex('-p')+1]) ||
                      "PID-#{Process.pid}"

  # CBRAIN plugins locations
  Plugins_Dir                = "#{Rails.root.to_s}/cbrain_plugins"
  UserfilesPlugins_Dir       = "#{Plugins_Dir}/installed-plugins/userfiles"
  TasksPlugins_Dir           = "#{Plugins_Dir}/installed-plugins/cbrain_task" # singular; historical
  TaskDescriptorsPlugins_Dir = "#{Plugins_Dir}/installed-plugins/cbrain_task_descriptors"

  CBRAIN_StartTime_Revision = CbrainFileRevision.cbrain_head_tag

  # Return current git branch for Cbrain, if no branch present resturn blank
  CBRAIN_Git_Branch = CbrainFileRevision.git_branch_name

  # Some environment variables MUST be set for some subsystems to work.
  # In deployment at McGill, we run the rails application under control
  # of 'monit' which clears the environment of almost everything!
  ENV['HOME'] = Rails_UserHome        # Most notably, ssh and Net::SFTP need this

  # File creation umask
  File.umask(0077)  # octal literal

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

    # Save the original DB connection and disconnect
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
          $0 = "#{taskname}\0" # Clever!
          Process.setpgrp rescue true

          $stdin.reopen( "/dev/null", "r") rescue true # fd 0
          $stdout.reopen("/dev/null", "w") rescue true # fd 1
          $stderr.reopen("/dev/null", "w") rescue true # fd 2

          # Try to find the RAILS acceptor socket(s) and close them.
          # We assume they'll be file descriptors that are
          # open read-write and non-blocking. If that's not
          # specific enough in the future, we'll need new logic here.
          # Debug code below left comment-out on purpose.
          expect_flags = Fcntl::O_RDWR | Fcntl::O_NONBLOCK
          (3..20).each do |fd|
            io = IO.for_fd(fd) rescue nil
            unless io
              #puts_red "FD #{fd} : not opened"
              next
            end
            flags = io.fcntl(Fcntl::F_GETFL) rescue 0x1000000 # chosen not to match the test below
            #puts_green "FD #{fd} : #{flags} AC=#{io.autoclose?}"
            io.autoclose=false # IMPORTANT!
            if (flags & expect_flags) == expect_flags
              io.autoclose=true # IMPORTANT!
              io.close rescue true
              #puts_cyan "-> Closed"
            end
          end

          # Reconnect to DB
          ActiveRecord::Base.establish_connection(dbconfig)

          # Execute the user code
          yield

        # Background untrapped exception handling
        rescue ActiveRecord::StatementInvalid, Mysql::Error
          puts "#{taskname} PID #{Process.pid}: Oh oh. The DB connection was closed! Nothing to do but exit!"
        rescue => itswrong
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

        writer.close # Not needed in the subchild!

        $stdin.reopen( "/dev/null", "r") rescue true # fd 0
        $stdout.reopen("/dev/null", "w") rescue true # fd 1
        $stderr.reopen("/dev/null", "w") rescue true # fd 2

        # Try to close all file descriptors from 3 to 50.
        (3..50).each { |i| IO.for_fd(i).close rescue true } # with some luck, it's enough

        # Background code execution
        begin
          $0 = "#{taskname}\0" # Clever!
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

  # Runs a block after having unlocked the SSH agent for the whole CBRAIN system.
  # If no block is given, unlocks the agent and returns true.
  def self.with_unlocked_agent(options = {})

    agent = SshAgent.find_current # cannot use find_by_name, because it has a name only on portal side

    if agent
      @_rr_name   ||= RemoteResource.current_resource.name rescue "UnknownServer"
      admin         = User.admin
      passphrase    = admin.meta[:global_ssh_agent_lock_passphrase] ||= User.random_string

      # Prepare info line about the unlocking event
      pretty_context = ""
      mytraces = caller.reject { |l| (l !~ /\/(BrainPortal|Bourreau)\//) || (l =~ /block in/) }
      mytrace  = mytraces[options[:caller_level] || 0]
      if mytrace.blank? # two alternative logging messages possible in this IF statement
        mytrace = mytraces[0].presence || caller[0]
        #pretty_context = sprintf("%s : Unlocking happened outside of CBRAIN codebase.",@_rr_name)
      end
      if pretty_context.blank? && mytrace.present? && mytrace =~ /([^\/]+):(\d+):in \`(\S+)\'/
        basename,linenum,method = Regexp.last_match[1,3] # means 1, 2 and 3
        pretty_context = sprintf("%s : %s() in file %s at line %d",@_rr_name, method, basename, linenum)
      end
      pretty_context = sprintf("%s : No known location",@_rr_name) if pretty_context.blank?

      SshAgentUnlockingEvent.create(:message => pretty_context)  # new record with message and timestamp
      agent.unlock(passphrase) # unlock the SshAgent; it will be relocked by the SshAgentLocker background process started on the Portal side.

    end

    block_given? ? yield : true
  end

end  # End of CBRAIN class

