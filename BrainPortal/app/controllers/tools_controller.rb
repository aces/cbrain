
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
    @tools     = current_user.available_tools.find(:all, :include  => [:bourreaux, :user, :group], :order  => "tools.name")
    
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @tools }
    end
  end
  
  def bourreau_select #:nodoc:
    if params[:current_value].blank?
      render :text  => ""
      return
    end
    
    @tool = current_user.available_tools.find(params[:current_value])
    @bourreaux = @tool.bourreaux.find_all_accessible_by_user(current_user, :conditions  => {:online  => true})
    @bourreaux.reject! do |b|
      tool_configs = ToolConfig.find(:all, :conditions => { :tool_id => @tool.id, :bourreau_id => b.id })
      ! ( tool_configs.detect { |tc| tc.can_be_accessed_by?(current_user) } ) # need at least one config available for user
    end
    
    respond_to do |format|
      format.html do 
        random_exec_prompt = @bourreaux.size > 1 ? { :include_blank  => "Random Execution Server" } : {}
        render :text  => ApplicationController.helpers.bourreau_select("bourreau_id", 
                            { :selector  => current_user.user_preference.bourreau_id.to_s,
                              :bourreaux  => @bourreaux
                            },
                            random_exec_prompt
                         )
      end
      format.xml  { render :xml => @bourreaux }
    end
    
  rescue
    render :text  => '<strong style="color:red">No Execution Servers Available</strong>'
  end

  # GET /tools/1/edit
  def edit #:nodoc:
    @tool      = current_user.available_tools.find(params[:id])
    @bourreaux = Bourreau.find_all_accessible_by_user(current_user)
  end

  # POST /tools
  # POST /tools.xml
  def create #:nodoc:

    if params[:autoload]
      self.autoload_all_tools
      return
    end

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

  def autoload_all_tools #:nodoc:

    successes = []
    failures  = ""

    PortalTask.send(:subclasses).map(&:name).sort.each do |tool|
      next if current_user.available_tools.find_by_cbrain_task_class(tool) # already exists
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
        successes << @tool
      else
        failures += "#{tool} could not be added.\n"
      end
    end

    respond_to do |format|
      if successes.size > 0
        flash[:notice] = "#{@template.pluralize(successes.size, "tool")} successfully registered:\n"
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
        format.js { render :text  => "jQuery('#tool_#{@tool.id}').remove();" }                                          
        format.xml  { head :ok }                              
      end                                                     
  end
      
  def tool_management #:nodoc:
      @tools = Tool.find(:all, :include  => [:bourreaux], :order  => "tools.name")
      @bourreaux = Bourreau.find(:all)
  end

end
