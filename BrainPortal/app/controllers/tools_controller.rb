
#
# CBRAIN Project
#
# Tool controller for the BrainPortal interface
#
# Original author: Angela McCloskey
#
# Revision_info="$Id$"
#

class ToolsController < ApplicationController
 
  Revision_info="$Id$"
 
  before_filter :login_required
  before_filter :admin_role_required, :except  => [:index, :bourreau_select]
 
  # GET /tools
  # GET /tools.xml
  def index #:nodoc:
    @tools = current_user.available_tools.find(:all, :include  => [:bourreaux, :user, :group], :order  => "tools.name")
    
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @tools }
    end
  end
  
  def bourreau_select #:nodoc:
    @tool = current_user.available_tools.find_by_cbrain_task_class(params[:cbrain_task_class])
    @bourreaux = @tool.bourreaux.all(:conditions  => {:id  => available_bourreaux})
    
    respond_to do |format|
      format.html { render :layout  => false, :partial  => 'userfiles/bourreau_select'}
      format.xml  { render :xml => @bourreaux }
    end
    
  rescue
    render :text  => ""
  end

  # GET /tools/1/edit
  def edit #:nodoc:
    @tool = current_user.available_tools.find(params[:id])
  end

  # POST /tools
  # POST /tools.xml
  def create #:nodoc:
    if params[:autoload]
      successes = 0
      failures  = ""
      CbrainTask::PortalTask.subclasses.sort.each do |tool|
        unless current_user.available_tools.find_by_cbrain_task_class(tool)
          @tool = Tool.new(
                      :name               => tool.sub(/^CbrainTask::/, ""),
                      :cbrain_task_class  => tool,
                      :bourreau_ids       => Bourreau.find_all_accessible_by_user(current_user).map(&:id),
                      :user_id            => User.find_by_login("admin").id,
                      :group_id           => Group.find_by_name("everyone").id,
                      :category           => "scientific tool" 
                    )
          success = @tool.save
          if success
            successes += 1
          else
            failures += "#{tool} could not be added.\n"
          end
        end
      end
      respond_to do |format|
        if successes > 0
          flash[:notice] = "#{@template.pluralize(successes, "tool")} successfully registered."
        else
          flash[:notice] = "No unregistered tools."
        end
        unless failures.blank?
          flash[:error] = failures
        end
        format.html {redirect_to tools_path}
      end
    else
      params[:tool][:bourreau_ids] ||= []
      @tool = Tool.new(params[:tool])
      respond_to do |format|
        if @tool.save
          flash[:notice] = 'Tool was successfully created.'
          format.js {render :partial  => 'shared/create', :locals  => {:model_name  => 'tool' }}
          format.xml  { render :xml => @tool, :status => :created, :location => @tool }
        else
          format.js {render :partial  => 'shared/create', :locals  => {:model_name  => 'tool' }}
          format.xml  { render :xml => @tool.errors, :status => :unprocessable_entity }
        end
      end
    end
  end

  # PUT /tools/1
  # PUT /tools/1.xml
  def update #:nodoc:
    params[:tool][:bourreau_ids] ||= []
    @tool = current_user.available_tools.find(params[:id])
    respond_to do |format|
      if @tool.update_attributes(params[:tool])
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
      format.js do
        render :update do |page|
          page["tool_#{@tool.id}"].remove
        end
      end
      format.xml  { head :ok }
    end
  end
  
  def tool_management #:nodoc:
      @tools = Tool.find(:all, :include  => [:bourreaux], :order  => "tools.name")
      @bourreaux = Bourreau.find(:all)
  end

end
