
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
class NeurohubController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  before_action :login_required
  before_action :check_if_rebooting

  # Main welcome/dashboard page
  def welcome #:nodoc:
    @username = current_user.login
  end

  # For development work convenience
  def reboot #:nodoc:
    root   = Pathname.new(Rails.root)
    cbroot = root.parent

    if params[:do_it].present?
      system("cp","public/reboot.txt.base", "public/reboot.txt")
      File.open("public/reboot.txt","a") do |fh|
        fh.write(
          "Reboot initiated by user #{current_user.login} at #{Time.now}. Server PID: #{CBRAIN::NH_PUMA_PID}\n\n"
        )
      end
      Dir.chdir(cbroot.to_s) do
        #ret = system("echo ABC | tee -a BrainPortal/public/reboot.txt")
        CBRAIN.spawn_fully_independent do
          ret = system("bash script/update_cb_all.sh #{root.to_s.bash_escape} >> BrainPortal/public/reboot.txt")
          Process.kill('TERM',CBRAIN::NH_PUMA_PID) if ret
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
