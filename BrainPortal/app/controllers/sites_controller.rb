#
# CBRAIN Project
#
# Controller for site resource.
#
# Original author: Tarek Sherif
#
# $Id$
#

#RESTful controller for the Site resource.
class SitesController < ApplicationController
  
  Revision_info = "$Id$"
  
  before_filter :login_required 
  before_filter :admin_role_required, :except  => :show
  
  # GET /sites
  # GET /sites.xml
  def index
    @sites = Site.find(:all, :include  => [:users, :groups])

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @sites }
    end
  end

  # GET /sites/1
  # GET /sites/1.xml
  def show
    @site = Site.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @site }
    end
  end

  # GET /sites/new
  # GET /sites/new.xml
  def new
    @site = Site.new
    @users  = User.all
    @groups = WorkGroup.all

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @site }
    end
  end

  # GET /sites/1/edit
  def edit
    @site = Site.find(params[:id])
    @users  = User.all
    @groups = WorkGroup.all
  end

  # POST /sites
  # POST /sites.xml
  def create
    @site = Site.new(params[:site])

    respond_to do |format|
      if @site.save
        flash[:notice] = 'Site was successfully created.'
        format.html { redirect_to(@site) }
        format.xml  { render :xml => @site, :status => :created, :location => @site }
      else
        @users  = User.all
        @groups = WorkGroup.all
        format.html { render :action => "new" }
        format.xml  { render :xml => @site.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /sites/1
  # PUT /sites/1.xml
  def update
    @site = Site.find(params[:id])
    params[:site][:user_ids] ||= []
    params[:site][:manager_ids] ||= []
    params[:site][:group_ids] ||= [SystemGroup.find_by_name(@site.name)]
    

    respond_to do |format|
      if @site.update_attributes(params[:site])
        flash[:notice] = 'Site was successfully updated.'
        format.html { redirect_to(@site) }
        format.xml  { head :ok }
      else
        @users  = User.all
        @groups = WorkGroup.all
        format.html { render :action => "edit" }
        format.xml  { render :xml => @site.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /sites/1
  # DELETE /sites/1.xml
  def destroy
    @site = Site.find(params[:id])
    @site.destroy

    respond_to do |format|
      format.html { redirect_to(sites_url) }
      format.xml  { head :ok }
    end
  end
end
