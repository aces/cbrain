
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

# Controller for managing Tool objects.
class ToolsController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  before_filter :login_required
  before_filter :admin_role_required, :except  => [:index, :tool_config_select]

  # GET /tools
  # GET /tools.xml
  def index #:nodoc:
    @scope = scope_from_session('tools')
    scope_default_order(@scope, 'name')

    @base_scope = current_user.available_tools.includes(:user, :group)
    @tools = @scope.apply(@base_scope)

    respond_to do |format|
      format.js
      format.html # index.html.erb
      format.xml  { render :xml => @tools }
    end
  end

  def tool_config_select #:nodoc:
    if params[:tool_id].blank?
      render :text  => ""
      return
    end

    tool_id       = params[:tool_id]
    @tool         = current_user.available_tools.find(tool_id)

    # All accessible bourreaux for this tool
    bourreau_ids  = @tool.bourreaux.map(&:id)
    @bourreaux    = Bourreau.find_all_accessible_by_user(current_user).where( :id => bourreau_ids)
    # All accessible tc for this tool on accessible bourreaux
    bourreaux_ids = @bourreaux.map(&:id)
    @tool_configs = ToolConfig.find_all_accessible_by_user(current_user).where(:tool_id => tool_id, :bourreau_id => bourreau_ids)
    # Reduce list of bourreaux, bourreaux need at least one config available
    bourreaux_ids = @tool_configs.map(&:bourreau_id)
    @bourreaux    = @bourreaux.where(:id => bourreaux_ids).all

    # Select a specific tool_config
    selected_by_default = current_user.meta["pref_bourreau_id"]
    @tool_config        = bourreaux_ids.include?(selected_by_default) && @bourreaux.detect? { |b| b.id == selected_by_default && b.online? } ?
                          @tool_configs.where(:bourreau_id => selected_by_default).last : nil

    respond_to do |format|
      format.html { render :partial => 'tools/tool_config_select' }
      format.xml  { render :xml     => @tool_configs }
    end

  rescue
    # render :text  => "#{ex.class} #{ex.message}\n#{ex.backtrace.join("\n")}"
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
      if @tool.save
        @tool.addlog_context(self,"Created by #{current_user.login}")
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
                  :user_id            => User.admin.id,
                  :group_id           => User.admin.own_group.id,
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
