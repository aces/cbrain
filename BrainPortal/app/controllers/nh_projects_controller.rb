
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

# Project management for NeuroHub
class NhProjectsController < NeurohubApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  before_action :login_required

  def edit #:nodoc:
    @nh_group = current_user.available_groups.where(:type => WorkGroup).find(params[:id])
  end

  def update #:nodoc:
    @nh_group      = current_user.available_groups.where(:type => WorkGroup).find(params[:id])

    attr_to_update = params.require_as_params(:nh_group).permit(:name, :description, :site_id, :invisible)
    @nh_group.update_attributes_with_logging(attr_to_update,current_user)

    redirect_to :action => "edit"
  end

end

