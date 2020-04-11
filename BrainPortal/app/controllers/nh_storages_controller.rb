
#
# NeuroHub Project
#
# Copyright (C) 2020
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

# Storage management for NeuroHub.
#
# The main data model is in fact CBRAIN's UserkeyFlatDirSshDataProvider
class NhStoragesController < NeurohubApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  before_action :login_required

  # A private exception class when testing connectivity
  class UserKeyTestConnectionError < RuntimeError ; end

  def new #:nodoc:
    @nh_dp = UserkeyFlatDirSshDataProvider.new
  end

  def show
    @nh_dp       = UserkeyFlatDirSshDataProvider.where(:user_id => current_user.id).find(params[:id])
    @file_counts = @nh_dp.userfiles.group(:type).count
    @file_sizes  = @nh_dp.userfiles.group(:type).sum(:size)
  end

  def create #:nodoc:
    attributes = params.require_as_params(:nh_dp)
                       .permit(:name       , :description,
                               :remote_user, :remote_host,
                               :remote_port, :remote_dir,
                              )
    @nh_dp = UserkeyFlatDirSshDataProvider.new(attributes)

    # Some constants
    @nh_dp.update_attributes(
      :user_id  => current_user.id,
      :group_id => current_user.own_group.id,
      :online   => true,
    )

    if @nh_dp.save
      @nh_dp.addlog_context(self,"Created by #{current_user.login}")
      @nh_dp.meta[:browse_gid] = current_user.own_group.id # only the owner can browse this in CBRAIN
      flash[:notice] = "Private storage #{@nh_dp.name} was successfully created"
      redirect_to :action => :show, :id => @nh_dp.id
    else
      flash[:error] = "Cannot create storage #{@nh_dp.name}"
      render :action => :new
    end
  end

  def index  #:nodoc:
    @nh_dps = UserkeyFlatDirSshDataProvider.where(:user_id => current_user.id)
  end

  def edit #:nodoc:
    @nh_dp = UserkeyFlatDirSshDataProvider.where(:user_id => current_user.id).find(params[:id])
  end

  def update #:nodoc:
    @nh_dp = UserkeyFlatDirSshDataProvider.where(:user_id => current_user.id).find(params[:id])
    attributes = params.require_as_params(:nh_dp)
                       .permit(:name       , :description,
                               :remote_user, :remote_host,
                               :remote_port, :remote_dir,
                              )
    success = @nh_dp.update_attributes_with_logging(attributes, current_user,
                     %i( remote_user remote_host remote_port remote_dir )
    )

    if success
      flash[:notice] = "Storage #{@nh_dp.name} was successfully updated."
      redirect_to :action => :show
    else
      flash.now[:error] = "Storage #{@nh_dp.name} could not be updated."
      render :action => :edit
    end
  end

  def destroy
    @nh_dp = UserkeyFlatDirSshDataProvider.where(:user_id => current_user.id).find(params[:id])
    if @nh_dp.destroy
      flash[:notice] = "Storage configuration #{@nh_dp.name} was successfully removed."
      redirect_to :action => :index
    else
      flash.now[:error] = "Storage configuration #{@nh_dp.name} could not be removed."
      redirect_to :action => :show
    end
  end

  def autoregister
    @nh_dp = UserkeyFlatDirSshDataProvider.where(:user_id => current_user.id).find(params[:id])
    cb_error 'NYI'
  end

  # This action checks that the remote side of the DataProvider is
  # accessible using SSH.
  def check
    @nh_dp = UserkeyFlatDirSshDataProvider.where(:user_id => current_user.id).find(params[:id])

    @nh_dp.update_column(:online, true)

    master  = @nh_dp.master # This is a handler for the connection, not persistent.
    tmpfile = "/tmp/dp_check.#{Process.pid}.#{rand(1000000)}"

    # Check #1: the SSH connection can be established
    if ! master.is_alive?
      test_error "Cannot establish the SSH connection. Check the configuration: username, hostname, port are valid, and SSH key is installed."
    end

    # Check #2: we can run "true" on the remote site and get no output
    status = master.remote_shell_command_reader("true",
      :stdin  => "/dev/null",
      :stdout => "#{tmpfile}.out",
      :stderr => "#{tmpfile}.err",
    )
    stdout = File.read("#{tmpfile}.out") rescue "Error capturing stdout"
    stderr = File.read("#{tmpfile}.err") rescue "Error capturing stderr"
    if stdout.size != 0
      stdout.strip! if stdout.present? # just to make it pretty while still reporting whitespace-only strings
      test_error "Remote shell is not clean: got some bytes on stdout: '#{stdout}'"
    end
    if stderr.size != 0
      stderr.strip! if stdout.present?
      test_error "Remote shell is not clean: got some bytes on stderr: '#{stderr}'"
    end
    if ! status
      test_error "Got non-zero return code when trying to run 'true' on remote side."
    end

    # Check #3: the remote directory exists
    master.remote_shell_command_reader "test -d #{@nh_dp.remote_dir.bash_escape} && echo DIR-OK", :stdout => tmpfile
    out = File.read(tmpfile)
    if out != "DIR-OK\n"
      test_error "The remote directory doesn't seem to exist."
    end

    # Check #4: the remote directory is readable
    master.remote_shell_command_reader "test -r #{@nh_dp.remote_dir.bash_escape} && test -x #{@nh_dp.remote_dir.bash_escape} && echo DIR-READ", :stdout => tmpfile
    out = File.read(tmpfile)
    if out != "DIR-READ\n"
      test_error "The remote directory doesn't seem to be readable"
    end

    # Ok, all is well.
    flash[:notice] = "The configuration was tested and seems to be operational."
    redirect_to :action => :show

  rescue UserKeyTestConnectionError => ex
    flash[:error]  = ex.message
    flash[:error] += "\nThis storage is marked as 'offline' until this test pass."
    @nh_dp.update_column(:online, false)
    redirect_to :action => :show

  ensure
    File.unlink "#{tmpfile}.out" rescue true
    File.unlink "#{tmpfile}.err" rescue true

  end

  private

  # Utility method to raise an exception
  # when testing for a DP's configuration.
  def test_error(message) #:nodoc:
    raise UserKeyTestConnectionError.new(message)
  end

end

