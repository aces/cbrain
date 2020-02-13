
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
  before_action :check_if_rebooting

  # Main welcome/dashboard page
  def welcome #:nodoc:
    @username = current_user.login
  end

  # For development work convenience; not part of final neurohub deliverable
  def reboot #:nodoc:
    root   = Pathname.new(Rails.root)
    cbroot = root.parent

    # When puma is in cluster mode, we must restart using the PPID.
    # Otherwise we must use our own PID.
    puma_pid  = Process.pid
    puma_ppid = Process.ppid

    parent_info = Sys::ProcTable.ps(:pid => puma_ppid)
    clustered   = parent_info.name == 'ruby'

    @pid_to_restart = clustered ? puma_ppid : puma_pid

    if params[:do_it].present?
      message = "Reboot initiated by user #{current_user.login} at #{Time.now}. Server PID: #{@pid_to_restart}"
      Rails.logger.info message

      system("cp","-p","public/reboot.txt.base", "public/reboot.txt")
      File.open("public/reboot.txt","a") { |fh| fh.write( message + "\n\n" ) }

      Dir.chdir(cbroot.to_s) do
        #ret = system("echo ABC | tee -a BrainPortal/public/reboot.txt")
        CBRAIN.spawn_fully_independent do
          ret = system("bash script/update_cb_all.sh #{root.to_s.bash_escape} >> BrainPortal/public/reboot.txt")
          if ret
            #Process.kill('USR1',@pid_to_restart) # note: a bug in Puma makes it not restart because of pid file 
            Process.kill('TERM',@pid_to_restart) # in production, monit will restart
          else
            message = "ERROR: The update processed returned an error code. Restart not attempted. Contact Pierre."
            File.open("public/reboot.txt","a") { |fh| fh.write( message + "\n\n" ) }
          end
        end
      end

      redirect_to '/reboot.txt'
      return
    end

    # Render reboot.html.erb
  end

  private

  def check_if_rebooting
    if File.exists? "public/reboot.txt"
      render :plain => File.read('public/reboot.txt').gsub(/\e\[[\d;]+m/,"")
    end
    true
  end

end
