
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

class ToolsController < ApplicationController
 
  Revision_info=CbrainFileRevision[__FILE__]
 
  before_filter :login_required
  before_filter :admin_role_required, :except  => [:index, :bourreau_select]
 
  # GET /tools
  # GET /tools.xml
  def index #:nodoc:
    @filter_params["sort_hash"]["order"] ||= 'tools.name'
    
    @header_scope   = current_user.available_tools
    @filtered_scope = base_filtered_scope(@header_scope.includes(:user, :group))
    @tools          = base_sorted_scope @filtered_scope
    
    respond_to do |format|
      format.js
      format.html # index.html.erb
      format.xml  { render :xml => @tools }
    end
  end
  
  def bourreau_select #:nodoc:
    if params[:tool_id].blank?
      render :text  => ""
      return
    end
    
    @tool        = current_user.available_tools.find(params[:tool_id])
    bourreau_ids = @tool.bourreaux.map &:id
    @bourreaux   = Bourreau.find_all_accessible_by_user(current_user).where( :id => bourreau_ids ).all
    @bourreaux.reject! do |b|
      tool_configs = ToolConfig.where( :tool_id => @tool.id, :bourreau_id => b.id )
      ! ( tool_configs.detect { |tc| tc.can_be_accessed_by?(current_user) } ) # need at least one config available for user
    end
    
    respond_to do |format|
      format.html { render :partial => 'tools/bourreau_select' }
      format.xml  { render :xml     => @bourreaux }
    end
    
  rescue => ex
    #render :text  => "#{ex.class} #{ex.message}\n#{ex.backtrace.join("\n")}"
    render :text  => '<strong style="color:red">No Execution Servers Available</strong>'
  end

  def new #:nodoc:
    @tool = Tool.new
    render :partial => "new"
  end

  # GET /tools/1/edit
  def edit #:nodoc:
    @tool      = current_user.available_tools.find(params[:id])
  end

  # POST /tools
  # POST /tools.xml
  def create #:nodoc:

    if params[:autoload]
      autoload_all_tools
      return
    end

    @tool = Tool.new(params[:tool])

    task_class = @tool.cbrain_task_class || "CbrainTask::Object"
    task_class = task_class.demodulize
    subclass = CbrainTask.const_get(task_class) rescue Object
    unless subclass < CbrainTask # strictly subclass
      @tool.errors.add(:cbrain_task_class, "doesn't seem to be a code subclass of CbrainTask.")
    end

    respond_to do |format|
      if @tool.errors.empty? && @tool.save
        flash[:notice] = 'Tool was successfully created.'
        format.js  { redirect_to :action => :index, :format => :js }
        format.xml { render :xml => @tool, :status => :created, :location => @tool }
      else
        format.js  { render :partial  => 'shared/failed_create', :locals  => {:model_name  => 'tool' } }
        format.xml { render :xml => @tool.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /tools/1
  # PUT /tools/1.xml
  def update #:nodoc:
    @tool = current_user.available_tools.find(params[:id])
    respond_to do |format|
      if @tool.update_attributes_with_logging(params[:tool], current_user, %w( category cbrain_task_class select_menu_text ) )
        flash[:notice] = 'Tool was successfully updated.'
        format.html { redirect_to(tools_path) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @tool.errors, :status => :unprocessable_entity }
      end
    end
  end
  
  
  # DELETE /tools/1                                 
    # DELETE /tools/1.xml                           
  def destroy #:nodoc:                              
      @tool = current_user.available_tools.find(params[:id])  
      @tool.destroy                                           
                                                              
      respond_to do |format|
        format.html { redirect_to :action => :index }
        format.js   { redirect_to :action => :index, :format => :js }                                          
        format.xml  { head :ok }                              
      end                                                     
  end
      
  private
  
  def autoload_all_tools #:nodoc:

    successes = []
    failures  = ""

    PortalTask.descendants.map(&:name).sort.each do |tool|
      next if current_user.available_tools.find_by_cbrain_task_class(tool) # already exists
      @tool = Tool.new(
                  :name               => tool.demodulize,
                  :cbrain_task_class  => tool,
                  :user_id            => User.find_by_login("admin").id,
                  :group_id           => Group.everyone.id,
                  :category           => "scientific tool" 
                )
      success = @tool.save
      if success
        successes << @tool
      else
        failures += "#{tool} could not be added.\n"
      end
    end

    respond_to do |format|
      if successes.size > 0
        flash[:notice] = "#{view_pluralize(successes.size, "tool")} successfully registered:\n"
        successes.each do |tool|
          flash[:notice] += "Name: #{tool.name} Class: #{tool.cbrain_task_class}\n"
        end
      else
        flash[:notice] = "No unregistered tools found."
      end
      unless failures.blank?
        flash[:error] = failures
      end
      format.html { redirect_to tools_path }
    end

  end

end
