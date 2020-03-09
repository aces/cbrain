
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
    attributes             = params.require_as_params(:nh_project).permit(:name, :description, :public, :editor_ids => [])

    @nh_project            = WorkGroup.new(attributes)
    @nh_project.creator_id = current_user.id

    if @nh_project.save
      @nh_project.user_ids = [ current_user.id ]
      @nh_project.addlog_context(self,"Created by #{current_user.login}")
      flash[:notice] = "Project #{nh_project.name} is successfully created"
      redirect_to :action => :show, :id => @nh_project.id
    else
      flash[:error] = "Cannot create project #{nh_project.name}"
      render :action => :new
    end
  end

  def index  #:nodoc:
    # Note: Should refactor to use session object instead of scope to store button state in the future.
    @nh_projects = find_nh_projects(current_user)
    @scope = scope_from_session
    @scope.custom[:button] = true if
      current_user.has_role?(:normal_user) && @scope.custom[:button].nil?
  end

  def edit #:nodoc:
    @nh_project = find_nh_project(current_user, params[:id])
  end

  def update #:nodoc:
    @nh_project    = find_nh_project(current_user, params[:id])

    unless @nh_project.can_be_edited_by?(current_user)
      flash[:error] = "You don't have permission to edit this project."
      redirect_to :action => :show
      return
    end

    attr_to_update = params.require_as_params(:nh_project).permit(:name, :description, :public, :editor_ids => [])
    success        = @nh_project.update_attributes_with_logging(attr_to_update,current_user)

    if success
      flash[:notice] = "Project #{@nh_project.name} is successfully updated."
      redirect_to :action => :show
    else
      flash.now[:error] = "Project #{@nh_project.name} is not successfully updated."
      render :action => :edit
    end
  end

  def show #:nodoc:
    @nh_project = find_nh_project(current_user, params[:id])
  end

  def files #:nodoc:
    @nh_project = find_nh_project(current_user, params[:id])
    @files      = @nh_project.userfiles
  end

end

