
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

  def new #:nodoc:
    @nh_project = WorkGroup.new
  end

  def create #:nodoc:
    attributes             = params.require_as_params(:nh_project).permit(:name, :description)

    @nh_project            = WorkGroup.new(attributes)
    @nh_project.creator_id = current_user.id

    if @nh_project.save
      @nh_project.user_ids = [ current_user.id ]
      @nh_project.addlog_context(self,"Created by #{current_user.login}")
      redirect_to :action => :edit, :id => @nh_project.id
    else
      render :action => :new
    end
  end

  def edit #:nodoc:
    @nh_project = current_user.available_groups.where(:type => WorkGroup).find(params[:id])
  end

  def update #:nodoc:
    @nh_project      = current_user.available_groups.where(:type => WorkGroup).find(params[:id])

    attr_to_update = params.require_as_params(:nh_project).permit(:name, :description)
    success = @nh_project.update_attributes_with_logging(attr_to_update,current_user)

    if success
      redirect_to :action => :edit
    else
      render :action => :edit
    end
  end

  # GET /projects/1
  # GET /projects/1.xml
  # GET /projects/1.json
  def show #:nodoc:
    @nh_project = current_user.available_groups.where(:type => WorkGroup).find(params[:id])
    raise ActiveRecord::RecordNotFound unless @nh_project.can_be_accessed_by?(current_user)
    @users = current_user.available_users.order(:login).reject { |u| u.class == CoreAdmin }

    respond_to do |format|
      format.html
      format.xml  { render :xml  => @nh_project.for_api }
      format.json { render :json => @nh_project.for_api }
    end
  end

end

