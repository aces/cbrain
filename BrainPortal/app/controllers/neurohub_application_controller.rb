
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

# Superclass to all *NeuroHub* controllers.
# Already inherits all the methods and modules of
# CBRAIN's ApplicationController.
class NeurohubApplicationController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  include NeurohubHelpers

  before_action :check_if_rebooting

  def check_if_rebooting
    if File.exists?("public/reboot_in_progress")
      render :plain => File.read('public/reboot.txt').gsub(/\e\[[\d;]+m/,"")
    end
    true
  end

end

