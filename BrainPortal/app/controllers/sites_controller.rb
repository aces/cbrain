
#
# CBRAIN Project
#
# Copyright (C) 2008-2012
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

#RESTful controller for the Site resource.
class SitesController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  before_action :login_required
  before_action :admin_role_required, :except  => :show
  before_action :site_membership_required, :only => :show

  # GET /sites
  # GET /sites.xml
  def index #:nodoc:
    @scope = scope_from_session('sites')
    scope_default_order(@scope, 'name')

    @sites = @scope.apply(Site.includes(:users, :groups))

    respond_to do |format|
      format.js
      format.html # index.html.erb
      format.xml  { render :xml => @sites }
    end
  end

  # GET /sites/1
  # GET /sites/1.xml
  def show #:nodoc:
    @site = current_user.has_role?(:admin_user) ? Site.find(params[:id]) : current_user.site

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @site }
    end
  end

  def new #:nodoc:
    @site = Site.new
  end

  # POST /sites
  # POST /sites.xml
  def create #:nodoc:
    @site = Site.new(site_params)

    respond_to do |format|
      if @site.save
        @site.addlog_context(self,"Created by '#{current_user.login}'")
        flash[:notice] = 'Site was successfully created.'
        format.html { redirect_to :action => :index, :format => :html }
        format.xml  { render :xml => @site, :status => :created, :location => @site }
      else
        format.html { render :action  => :new }
        format.xml  { render :xml => @site.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /sites/1
  # PUT /sites/1.xml
  def update #:nodoc:
    @site = Site.find(params[:id])

    new_site_attr = site_params

    original_user_ids    = @site.user_ids
    original_manager_ids = @site.managers.raw_first_column(&:id)
    original_group_ids   = @site.group_ids

    commit_name = extract_params_key([ :update_users, :update_groups ])

    unless commit_name == :update_users
      new_site_attr[:user_ids]    = original_user_ids    # we need to make sure they stay the same
      new_site_attr[:manager_ids] = original_manager_ids # we need to make sure they stay the same
    end

    unless commit_name == :update_groups
      new_site_attr[:group_ids] = original_group_ids    # we need to make sure they stay the same
    end

    new_site_attr[:user_ids]      = [] if new_site_attr[:user_ids].blank?
    new_site_attr[:manager_ids]   = [] if new_site_attr[:manager_ids].blank?
    new_site_attr[:group_ids]     = [ @site.own_group.id ] if new_site_attr[:group_ids].blank?
    new_site_attr[:user_ids]      = new_site_attr[:user_ids].reject(&:blank?).map(&:to_i)
    new_site_attr[:manager_ids]   = new_site_attr[:manager_ids].reject(&:blank?).map(&:to_i)
    new_site_attr[:group_ids]     = new_site_attr[:group_ids].reject(&:blank?).map(&:to_i)

    @site.unset_managers

    respond_to do |format|
      if @site.update_attributes_with_logging(new_site_attr, current_user)
        @site.reload
        @site.addlog_object_list_updated("Users",    User,  original_user_ids,    @site.user_ids,                        current_user, :login)
        @site.addlog_object_list_updated("Managers", User,  original_manager_ids, @site.managers.raw_first_column(&:id), current_user, :login)
        @site.addlog_object_list_updated("Groups",   Group, original_group_ids,   @site.group_ids,                       current_user)
        flash[:notice] = 'Site was successfully updated.'
        format.html { redirect_to(@site) }
        format.xml  { head :ok }
      else
        @site.restore_managers
        @site.reload
        format.html { render :action => "show" }
        format.xml  { render :xml => @site.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /sites/1
  # DELETE /sites/1.xml
  def destroy #:nodoc:
    @site = Site.find(params[:id])
    @site.destroy

    respond_to do |format|
      format.html { redirect_to :action => :index }
      format.js   { redirect_to :action => :index, :format => :js }
      format.xml  { head :ok }
    end
  end

  private

  def site_params #:nodoc:
    params.require(:site).permit(:name, :description, :user_ids => [], :manager_ids => [], :group_ids => [])
  end
end
