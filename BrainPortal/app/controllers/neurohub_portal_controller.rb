
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

# Controller for the entry point into the system.
class NeurohubPortalController < NeurohubApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  before_action :login_required

  # Main welcome/dashboard page
  def welcome #:nodoc:
    @username = current_user.login
    bourreau_ids = Bourreau.find_all_accessible_by_user(current_user).raw_first_column("remote_resources.id")
    user_ids     = current_user.available_users.raw_first_column(:id)
    @tasks       = CbrainTask.real_tasks.not_archived.where(:user_id => user_ids, :bourreau_id => bourreau_ids).order( "updated_at DESC" ).limit(5).all
    @files       = Userfile.find_all_accessible_by_user(current_user).where(:hidden => false).order( "updated_at DESC" ).limit(5).all
    @reboot_manager_user_ids = reboot_manager_user_ids
  end

  # For development work convenience; not part of final neurohub deliverable
  def reboot #:nodoc:

    if ! reboot_manager_user_ids.include?(current_user.id)
      flash[:error] = "Reboot manager not accessible for this user"
      redirect_to neurohub_path
      return
    end

    root   = Pathname.new(Rails.root)
    cbroot = root.parent

    # When puma is in cluster mode, we must restart using the PPID.
    # Otherwise we must use our own PID.
    puma_pid  = Process.pid
    puma_ppid = Process.ppid

    parent_info = Sys::ProcTable.ps(:pid => puma_ppid)
    clustered   = parent_info.name == 'ruby'

    @pid_to_restart = clustered ? puma_ppid : puma_pid

    if params[:do_it].present? && ! File.exists?("public/reboot_in_progress")
      system("touch","public/reboot_in_progress") # removed by BrainPortal/config/initializers/z1_neurohub_reboot_cleaner.rb
      system("cp","-p","public/reboot.txt.base", "public/reboot.txt")

      message = "Reboot initiated by user #{current_user.login} at #{Time.now}. Server PID: #{@pid_to_restart}"
      Rails.logger.info message
      File.open("public/reboot.txt","a") { |fh| fh.write( message + "\n\n" ) }

      Dir.chdir(cbroot.to_s) do
        #ret = system("echo ABC | tee -a BrainPortal/public/reboot.txt")
        CBRAIN.spawn_fully_independent do
          ret = system("bash script/update_cb_all.sh #{root.to_s.bash_escape} >> BrainPortal/public/reboot.txt")
          if ret
            Process.kill('TERM',@pid_to_restart) # in production, monit will restart
          else
            message = "ERROR: The update process returned an error code. Restart not attempted. Contact Pierre."
            File.open("public/reboot.txt","a") { |fh| fh.write( message + "\n\n" ) }
          end
        end
      end

      redirect_to '/reboot.txt'
      return
    end

    # Render reboot.html.erb
  end

  # This action searches among all sorts of models for IDs or strings,
  # and reports links to the matches found.
  def search
    @search   = params[:search]
    limit     = 20 # used by interface only

    report    = neurohub_search(@search,limit)

    @files    = report[:files]
    @tasks    = report[:tasks]
    @projects = report[:projects]
  end

  private

  # Returns the list of user IDs for users that have access
  # to the reboot manager. The list is maintained by
  # the main admin account, in a WorkGroup called
  # 'nh_reboot_manager_access' which must be invisible.
  # If the WorkGroup doesn't exist, only the main admin
  # can access it.
  def reboot_manager_user_ids
    access_group = WorkGroup.where( # must be created by admin
      :name       => 'nh_reboot_manager_access',
      :invisible  => true,
      :creator_id => AdminUser.admin.id,
    ).first

    return [ AdminUser.admin.id ] if ! access_group # not configured? Only admin can access it

    access_group.user_ids
  end

end

