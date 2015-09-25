
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

  before_filter :login_required
  before_filter :admin_role_required, :except  => :show
  before_filter :site_membership_required, :only => :show

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
    render :partial => "new"
  end

  # POST /sites
  # POST /sites.xml
  def create #:nodoc:
    @site = Site.new(params[:site])

    respond_to do |format|
      if @site.save
        @site.addlog_context(self,"Created by '#{current_user.login}'")
        flash[:notice] = 'Site was successfully created.'
        format.js  { redirect_to :action => :index, :format => :js }
        format.xml { render :xml => @site, :status => :created, :location => @site }
      else
        format.js  {render :partial  => 'shared/failed_create', :locals  => {:model_name  => 'site' }}
        format.xml { render :xml => @site.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /sites/1
  # PUT /sites/1.xml
  def update #:nodoc:
    @site = Site.find(params[:id])

    params[:site] ||= {}

    original_user_ids    = @site.user_ids
    original_manager_ids = @site.managers.raw_first_column(&:id)
    original_group_ids   = @site.group_ids

    commit_name = extract_params_key([ :update_users, :update_groups ])

    unless commit_name == :update_users
      params[:site][:user_ids]    = original_user_ids    # we need to make sure they stay the same
      params[:site][:manager_ids] = original_manager_ids # we need to make sure they stay the same
    end

    unless commit_name == :update_groups
      params[:site][:group_ids] = original_group_ids    # we need to make sure they stay the same
    end

    params[:site][:user_ids]      = [] if params[:site][:user_ids].blank?
    params[:site][:manager_ids]   = [] if params[:site][:manager_ids].blank?
    params[:site][:group_ids]     = [ @site.own_group.id ] if params[:site][:group_ids].blank?
    params[:site][:user_ids]      = params[:site][:user_ids].reject(&:blank?).map(&:to_i)
    params[:site][:manager_ids]   = params[:site][:manager_ids].reject(&:blank?).map(&:to_i)
    params[:site][:group_ids]     = params[:site][:group_ids].reject(&:blank?).map(&:to_i)

    @site.unset_managers

    respond_to do |format|
      if @site.update_attributes_with_logging(params[:site], current_user)
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
end
