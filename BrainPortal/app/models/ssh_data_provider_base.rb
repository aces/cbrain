
#
# CBRAIN Project
#
# Copyright (C) 2008-2020
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

# This module provides utility methods for DataProviders
# connecting to exterior systems using SSH and Net::SFTP.
#
# All utility methods in this module contain the
# two optional arguments user=nil,userfile=nil ;
# although not used here, these can be used by subclasses
# overriding the methods so that the behavior of the
# remote connections change depending on a 'user' or
# on a 'userfile'.
module SshDataProviderBase

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def net_sftp(user = nil, userfile = nil) #:nodoc:

    # Stupidly, some SSHDs insist on having 'keyboard-interactive' in the :auth_methods
    # even if we're not planning ot use it. Probably because of 2FA.
    Net::SFTP.start(remote_host, remote_user, :port => (remote_port.presence || 22), :auth_methods => [ 'publickey', 'keyboard-interactive' ] ) do |sftp|
      yield sftp
    end
  end

  # Builds a prefix for a +rsync+ command, such as
  #
  #   "rsync -e 'ssh -x -o a=b -o c=d -p port user@host'"
  #
  # Note that this means that remote file specifications for
  # rsync MUST start with a bare ":" :
  #
  #   rsync -e 'ssh_options_here user_host'  :/remote/file  local/file
  #
  # The user and userfile parameters are not used here, but in subclasses
  # the information there could be used to adjust the prefix returned.
  def rsync_over_ssh_prefix(user = nil, userfile = nil)
    ssh_opts = self.ssh_shared_options(user, userfile)
    ssh      = "ssh -q -x #{ssh_opts}"
    rsync    = "rsync -e #{shell_escape(ssh)}"
    rsync
  end

  # Returns the necessary options to connect to a master SSH
  # command running in the background (which will be started if
  # necessary).
  #
  # The +userfile+ parameter is not used here, but in subclasses
  # the information there could be use to adjust options returned.
  def ssh_shared_options(user = nil, userfile = nil)
    self.master(user, userfile).ssh_shared_options("auto") # ControlMaster=auto
  end

  # Returns the SshMaster object handling the persistent connection to the Provider side.
  # This incurs a costs, but increases security. Every access to this method
  # will also, as a side effect, unlock the global CBRAIN SSH agent.
  # This will open a N seconds window to perform a SSH or SFTP operation
  # on the connection (N is configured in the AgentLocker subprocess).
  #
  # Addendum, Aug 1st 2012: the connection is no longer necessary persistent, by
  # passing the :nomaster=true option to SshMaster when on a Bourreau!
  def master(user = nil, userfile = nil)
    prepare_master(user, userfile) if ! @master
    # Unlock agent, in preparation for doing stuff on it
    CBRAIN.with_unlocked_agent(:caller_level => 1)
    @master.start("DataProvider_#{self.name}") # does nothing is it's already started, or not persistent
    @master
  end

  def prepare_master(user = nil, userfile = nil) #:nodoc:
    myself     = RemoteResource.current_resource
    persistent = myself.meta[:use_persistent_ssh_masters_for_dps] # true, false, or string versions
    # Default 'persistent' is TRUE for BrainPortals, FALSE for others (e.g. Bourreaux)
    persistent = myself.is_a?(BrainPortal) if persistent.to_s !~ /\A(true|false)\z/
    ssh_config_options = self.meta[:ssh_config_options].presence || {} # sysadmin's config, if any
    @master = SshMaster.find_or_create(remote_user,remote_host,remote_port,
                :category           => "DP_#{Process.uid}",
                :uniq               => self.id.to_s,
                :nomaster           => (persistent.to_s != 'true'),
                :ssh_config_options => ssh_config_options,
              )
  end

  # Returns the stdout of 'command' as executed on the Provider side
  # through the ssh tunnel. stdin is redirected from /dev/null.
  def remote_bash_this(command, user = nil, userfile = nil)
    text = ""
    self.master(user, userfile).remote_shell_command_reader(command, :stdin => '/dev/null') do |fh|
      text = fh.read
    end

    filter_out_ssh_stderr_messages(text)
  end

  # Same as superclass, but because we sometimes issue local commands
  # that indirectly connect through ssh, we also filter out the same error
  # messages as in remote_bash_this().
  def bash_this(command) #:nodoc:
    text = super
    filter_out_ssh_stderr_messages(text)
  end

  private

  # Remove common warning messages generally printed on stderr...
  def filter_out_ssh_stderr_messages(text)
    # 1) From ssh
    text.sub!(/^Warning: Permanently added[^\n]+known hosts.\s*/i,"") # a common annoying warning

    # 1) From ssh-keysign when ssh to localhost from a different GID
    text.sub!(/^setresgid \d+: Operation not permitted\s*/i,"")
    text.sub!(/^ssh_keysign: no reply\s*/i,"")
    text.sub!(/^sign using hostkey.*failed\s*/i,"")
    text
  end

end

