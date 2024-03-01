
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

# This provider type is basically identical to
# the FlatDirSshDataProvider, but authenticates
# to the remote site using the SshKey of the
# owner of the data provider.
class UserkeyFlatDirSshDataProvider < FlatDirSshDataProvider

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  validates_presence_of :remote_user, :remote_host, :remote_dir

  api_attr_visible :remote_user, :remote_host, :remote_dir, :remote_port

  def impl_is_alive? #:nodoc:
    user = self.user # we use the owner as the way to check if it's alive
    return false unless self.master(user, nil).is_alive?
    remote_cmd = "test -d #{self.remote_dir.bash_escape} && echo OK-Dir 2>&1"
    text = self.remote_bash_this(remote_cmd, user, nil)
    return(text =~ /OK-Dir/ ? true : false)
  rescue
    false
  end

  def net_sftp(user = nil, userfile = nil) #:nodoc:
    user    = self.user # forced use of the DP owner as the connection ssh user
    key     = user.ssh_key
    id_file = key.send(:private_key_path)

    # Stupidly, some SSHDs insist on having 'keyboard-interactive' in the :auth_methods
    # even if we're not planning ot use it. Probably because of 2FA.
    Net::SFTP.start(remote_host, remote_user,
        :port         => (remote_port.presence || 22),
        :use_agent    => false,
        :auth_methods => [ 'publickey', 'keyboard-interactive' ],
        :keys         => [ id_file ]
    ) do |sftp|
      yield sftp
    end
  end

  def master(user = nil, userfile = nil) #:nodoc:
    user = self.user # forced use of the DP owner as the connection ssh user
    prepare_master(user, userfile) # unlike in SshDataProviderBase, no need to unlock agent, or start the master.
    @master
  end

  def prepare_master(user = nil, userfile = nil) #:nodoc:
    ssh_config_options = self.meta[:ssh_config_options].presence || {} # sysadmin's options, if any
    ssh_config_options = ssh_config_options.merge(
      {
        :IdentityFile   => user.ssh_key.send(:private_key_path).to_s,
        :IdentitiesOnly => :yes,
      }
    )
    @master = SshMaster.find_or_create(remote_user, remote_host, remote_port,
                :category           => "DP_#{Process.uid}",
                :uniq               => self.id.to_s,
                :nomaster           => true, # we never launch a persistent SSH master for the DP
                :ssh_config_options => ssh_config_options,
              )
    @master
  end

  # Override the superclass builder for the SSH options
  # so that we use the userfile's owner's SSH key identity.
  def ssh_shared_options(user = nil, userfile = nil) #:nodoc:
    user = self.user # forced use of the DP owner as the connection ssh user
    # no need to add "-i identityfile" because we'll get it with "-o IdentityFile=file" instead
    self.master(user, userfile).ssh_shared_options
  end

  #################################################################
  # Model Callbacks
  #################################################################

  # Normally, DPs can only be owned by admins. However, this DP class
  # can also be created by normal users.
  def owner_is_appropriate #:nodoc:
    return true
  end

end

