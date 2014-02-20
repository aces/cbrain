
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

# A controller for VMFactories.

class VmFactoriesController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  before_filter :login_required,        :except => [:request_password, :send_password]  
  before_filter :manager_role_required, :except => [:show, :edit, :update, :request_password, :send_password, :change_password]  
  
  def index #:nodoc:
   
    
    respond_to do |format|
      format.html # index.html.erb
      format.js
      format.xml  { render :xml => @users }
    end
  end
  
  # GET /user/1
  # GET /user/1.xml
  def show #:nodoc:
    @vm_factory = VmFactory.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @vm_factory }
    end
  end

  # Starts the VM factory. 
  def start
    @vm_factory = VmFactoryRoundRobin.find(params[:id])
    cb_error "VM Factory #{@vm_factory.id} is already alive" unless !@vm_factory.alive?
    @vm_factory.start
    cb_notice "VM Factory #{@vm_factory.id} started (round robin)"
  end

  # Stops the VM factory.
  def stop
    @vm_factory = VmFactory.find(params[:id])
    cb_error "VM Factory #{@vm_factory.id} is not alive" unless @vm_factory.alive?
    @vm_factory.stop
    cb_notice "VM Factory #{@vm_factory.id} stoped"
  end

  def new #:nodoc:
    @vm_factory = VmFactory.new
    render :partial => "new"
  end

  def create #:nodoc:

    params[:vm_factory] ||= {}
    fields = params[:vm_factory]

    @vm_factory = VmFactory.new ( fields )
    @vm_factory.name = params[:name]
    
    flash[:notice] = "#{fields}"
    if @vm_factory.save
      flash[:notice] = "VM Factory successfully created #{fields}."
      @vm_factory.addlog_context(self,"VM Factory created by '#{current_user.login}'")
      respond_to do |format|
        format.js  { redirect_to :action => :index, :format => :js }
        format.xml { render :xml => @vm_factory }
      end
    else
      respond_to do |format|                                                                  
        format.js  { render :partial  => 'shared/failed_create', :locals  => { :model_name  => 'vm_factory' } }
        format.xml { render :xml => @vm_factory.errors, :status => :unprocessable_entity }
      end
    end
  end

  def update #:nodoc:
    id = params[:id]
    @vm_factory = VmFactory.find(id) 
    
    fields = params[:vm_factory]
    fields ||= {}
    
    if @vm_factory.update_attributes_with_logging(fields, current_user, %w( name disk_image_file_id tau mu_plus mu_minus nu_plus nu_minus k_plus k_minus) )
      flash[:notice] = "VM Factory successfully updated."
      respond_to do |format|
        format.html { redirect_to :action => :show }
        format.xml  { render :xml  => @vm_factory }
      end
    else 
      @vm_factory.reload
      respond_to do |format|
        format.html { render :action => 'show' }
        format.xml  { render :xml  => @vm_factory.errors, :status  => :unprocessable_entity }
      end
    end
  end

  def destroy #:nodoc:
    if current_user.has_role? :admin_user
      @vm_factory = VmFactory.find(params[:id])
    end
    
    @vm_factory.destroy 
    
    flash[:notice] = "VM Factory '#{@vm_factory.name}' (id: #{@vm_factory.id}) destroyed" 

    respond_to do |format|
      format.html { redirect_to :action => :index }
      format.js   { redirect_to :action => :index, :format => :js}
      format.xml  { head :ok }
    end
  rescue ActiveRecord::DeleteRestrictionError => e
    flash[:error]  = "VM Factory not destroyed: #{e.message}"
    
    respond_to do |format|
      format.html { redirect_to :action => :index }
      format.js   { redirect_to :action => :index, :format => :js}
      format.xml  { head :conflict }
    end
  end

end
