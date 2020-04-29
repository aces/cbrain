
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
    @nh_dp       = UserkeyFlatDirSshDataProvider.new
    @nh_projects = find_nh_projects(current_user)
    @nh_projects = ensure_assignable_nh_projects(current_user, @nh_projects)
    @def_proj_id = params[:group_id] # can be nil or invalid, makes no diff, just a default for select box
  end

  def show
    @nh_dp       = find_nh_storage(current_user, params[:id])
    @file_counts = @nh_dp.userfiles.group(:type).count
    @file_sizes  = @nh_dp.userfiles.group(:type).sum(:size)
  end

  def create #:nodoc:
    attributes = params.require_as_params(:nh_dp)
                       .permit(:name       , :description, :group_id,
                               :remote_user, :remote_host,
                               :remote_port, :remote_dir,
                              )

    # Make sure project is allowed
    nh_project   = find_nh_project(current_user, attributes[:group_id]) rescue nil
    nh_project &&= ensure_assignable_nh_projects(current_user, nh_project) rescue nil
    attributes.delete(:group_id) if nh_project.nil? # will cause validation error and form redisplayed

    # Set the basic attributes from the form
    @nh_dp = UserkeyFlatDirSshDataProvider.new(attributes)

    # Some constant attributes
    @nh_dp.update_attributes(
      :user_id  => current_user.id,
      :online   => true,
    )

    # Save
    if @nh_dp.save
      @nh_dp.addlog_context(self,"Created by #{current_user.login}")
      @nh_dp.meta[:browse_gid] = current_user.own_group.id # only the owner can browse this in CBRAIN
      flash[:notice] = "Private storage #{@nh_dp.name} was successfully created"
      redirect_to :action => :show, :id => @nh_dp.id
    else
      @nh_projects = find_nh_projects(current_user) # for form
      @nh_projects = ensure_assignable_nh_projects(current_user, @nh_projects)
      flash[:error] = "Cannot create storage #{@nh_dp.name}"
      render :action => :new
    end
  end

  def index  #:nodoc:
    @nh_dps = find_all_nh_storages(current_user)
  end

  def edit #:nodoc:
    @nh_dp       = find_nh_storage(current_user, params[:id])
    @nh_projects = find_nh_projects(current_user)
    @nh_projects = ensure_assignable_nh_projects(current_user, @nh_projects)
  end

  def update #:nodoc:
    @nh_dp = find_nh_storage(current_user, params[:id])
    attributes = params.require_as_params(:nh_dp)
                       .permit(:name       , :description, :group_id,
                               :remote_user, :remote_host,
                               :remote_port, :remote_dir,
                              )
    # Make sure project is allowed
    nh_project   = find_nh_project(current_user, attributes[:group_id]) rescue nil
    nh_project &&= ensure_assignable_nh_projects(current_user, nh_project) rescue nil
    attributes.delete(:group_id) if nh_project.nil?

    # Update all
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
    @nh_dp = find_nh_storage(current_user, params[:id])
    @nh_dp.userfiles.to_a.each do |f|
      f.send :track_resource_usage_destroy # private method
      f.delete # remove from DB; does not remove content on provider side; no callbacks...
      f.destroy_log # ... so we clean up here
      f.destroy_all_meta_data # ... and here.
    end
    @nh_dp.reload # because userfile assoc has changed
    if @nh_dp.destroy
      flash[:notice] = "Storage configuration #{@nh_dp.name} was successfully removed."
      redirect_to :action => :index
    else
      flash.now[:error] = "Storage configuration #{@nh_dp.name} could not be removed."
      redirect_to :action => :show
    end
  end

  def autoregister
    @nh_dp = find_nh_storage(current_user, params[:id])

    # Contact remote site and get list of files there
    fileinfos = BrowseProviderFileCaching.get_recent_provider_list_all(@nh_dp, current_user)

    # Get currently registered files on DP
    registered = Userfile.where( :data_provider_id => @nh_dp.id )

    # Match them together
    FileInfo.array_match_all_userfiles(fileinfos, registered)

    # Make validation checks
    FileInfo.array_validate_for_registration(fileinfos)

    # Register all new ones
    added_ids = []
    fileinfos.select do |fi|
      fi.userfile.blank? &&
      (fi.symbolic_type == :regular || fi.symbolic_type == :directory)
    end.each do |fi|

      basename = fi.name

      # Guess best type
      type     = Userfile.suggested_file_type(basename) || SingleFile
      type     = FileCollection if fi.symbolic_type == :directory && ! (type < FileCollection)

      # Make the object
      userfile = type.new(
        :name             => basename,
        :user_id          => current_user.id,
        :group_id         => @nh_dp.group_id,
        :data_provider_id => @nh_dp.id,
        :group_writable   => false,
        :size             => (fi.symbolic_type == :regular ? fi.size : nil), # dir sizes set later
        :num_files        => (fi.symbolic_type == :regular ? 1       : nil),
      )
      if userfile.save
        added_ids << userfile.id
        userfile.addlog("Registered on storage '#{@nh_dp.name}'.")
      end

    end

    # Start size+num_files calculation in background
    todo = Userfile.where(:id => added_ids, :size => nil)
    CBRAIN.spawn_with_active_records_if(todo.count > 0, current_user, "Adjust file sizes") do
      todo.each do |file|
        file.set_size rescue nil
      end
    end

    # TODO: auto-deregister missing files?

    # Report
    @file_counts = Userfile.where(:id => added_ids).group(:type).count
    @file_sizes  = Userfile.where(:id => added_ids).group(:type).sum(:size)
    flash.now[:notice] = "Registered #{view_pluralize(added_ids.size,"new file")}"
    render :action => :registered_report

  end

  # This action checks that the remote side of the DataProvider is
  # accessible using SSH.
  def check
    @nh_dp = find_nh_storage(current_user, params[:id])

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

