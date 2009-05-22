
#
# CBRAIN Project
#
# Institutions controller for the BrainPortal interface
#
# Original author: Tarek Sherif
#
# $Id$
#

class InstitutionsController < ApplicationController

  Revision_info="$Id$"

  before_filter :login_required, :admin_role_required

  # GET /institutions
  # GET /institutions.xml
  def index
    @institutions = Institution.find(:all)

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @institutions }
    end
  end

  # GET /institutions/new
  # GET /institutions/new.xml
  def new
    @institution = Institution.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @institution }
    end
  end

  # GET /institutions/1/edit
  def edit
    @institution = Institution.find(params[:id])
    @groups = Group.find(:all)
  end

  # POST /institutions
  # POST /institutions.xml
  def create
    @institution = Institution.new(params[:institution])

    respond_to do |format|
      if @institution.save
        flash[:notice] = 'Institution was successfully created.'
        format.html { redirect_to institutions_path }
        format.xml  { render :xml => @institution, :status => :created, :location => @institution }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @institution.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /institutions/1
  # PUT /institutions/1.xml
  def update

    @institution = Institution.find(params[:id], :include => :groups)
    #params[:institution][:group_id] ||= []

    respond_to do |format|
      if @institution.update_attributes(params[:institution])
        flash[:notice] = 'Institution was successfully updated.'
        format.html { redirect_to institutions_path  }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @institution.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /institutions/1
  # DELETE /institutions/1.xml
  def destroy
    @institution = Institution.find(params[:id])
    @institution.destroy

    respond_to do |format|
      format.html { redirect_to(institutions_url) }
      format.xml  { head :ok }
    end
  end
end
