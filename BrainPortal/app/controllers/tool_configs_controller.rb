
#
# CBRAIN Project
#
# Original author: Pierre Rioux
#
# $Id$
#

class ToolConfigsController < ApplicationController
  
  Revision_info="$Id$"

  before_filter :login_required
  before_filter :admin_role_required

  def show #:nodoc:
    id     = params[:id]
    config = ToolConfig.find(id)

    @tool_config          = nil
    @tool_glob_config     = nil
    @bourreau_glob_config = nil
    
    @tool_config          = config if config.tool_id && config.bourreau_id
    @tool_glob_config     = ToolConfig.find(:first, :conditions =>
      { :tool_id => config.tool_id, :bourreau_id => nil }) if config.tool_id
    @bourreau_glob_config = ToolConfig.find(:first, :conditions =>
      { :tool_id => nil,            :bourreau_id => config.bourreau_id }) if config.bourreau_id
  end

  # The 'new' action is special in this controller.
  #
  # We need tool_id and bourreau_id as params; one or the other can be
  # nil but not both. A single potentially pre-existing object
  # will be accessed per pair of tool_id and bourreau_id when one of
  # them is nil. A brand new object is created when they are both
  # provided.
  def new
    tool_id     = params[:tool_id]
    bourreau_id = params[:bourreau_id]
    tool_id     = nil if tool_id.blank?     # allowed, means ALL tools
    bourreau_id = nil if bourreau_id.blank? # allowed, means ALL remote resources
    cb_error "Need at least one of tool ID or bourreau ID." unless tool_id || bourreau_id

    @tool_config   = ToolConfig.find(:first, :conditions => { :tool_id => tool_id, :bourreau_id => bourreau_id } ) if tool_id.blank? || bourreau_id.blank?
    @tool_config ||= ToolConfig.new(                        { :tool_id => tool_id, :bourreau_id => bourreau_id } )

    @tool_config.env_array ||= []

    @tool_config.group_id = Group.find_by_name("everyone")

    respond_to do |format|
      format.html { render :action => :edit }
      format.xml  { render :xml => @tool_config }
    end
  end

  def edit #:nodoc:
    id           = params[:id]
    @tool_config = ToolConfig.find(id)
    @tool_config.env_array ||= []

    @tool_config.group_id = Group.find_by_name("everyone") if @tool_config.group_id.blank?
      
    respond_to do |format|
      format.html # edit.html.erb
      format.xml  { render :xml => @tool_config }
    end
  end

  # Also used instead of create()
  # This method is special in that only one instance of
  # an object is permitted to exist for a pair of [:tool_id, :bourreau_id],
  # so an object being created is FIRST loaded from the DB if it exists to
  # prevent duplication.
  def update #:nodoc:
    id                = params[:id] || "NEW" # can be 'new' if we create()
    id                = nil if id == "NEW"
    form_tool_config  = ToolConfig.new(params[:tool_config]) # just to store the new attributes
    form_tool_id      = form_tool_config.tool_id
    form_tool_id      = nil if form_tool_id.blank?
    form_bourreau_id  = form_tool_config.bourreau_id
    form_bourreau_id  = nil if form_bourreau_id.blank?

    @tool_config   = nil
    @tool_config   = ToolConfig.find(id) unless id.blank?
    cb_error "Need at least one of tool ID or bourreau ID." if @tool_config.blank? && form_tool_id.blank? && form_bourreau_id.blank?
    @tool_config ||= ToolConfig.find(:first, :conditions => { :tool_id => form_tool_id, :bourreau_id => form_bourreau_id } ) if form_tool_id.blank? || form_bourreau_id.blank?
    @tool_config ||= ToolConfig.new(                        { :tool_id => form_tool_id, :bourreau_id => form_bourreau_id } )

    # Security: no matter what the form says, we use the ids from the DB if the object existed.
    form_tool_config.tool_id     = @tool_config.tool_id
    form_tool_config.bourreau_id = @tool_config.bourreau_id

    # Update everything else
    [ :description, :script_prologue, :group_id ].each do |att|
       @tool_config[att] = form_tool_config[att]
    end

    @tool_config.env_array = []
    envlist = params[:env_list] || []
    envlist.each do |keyval|
       env_name = keyval[:name].strip
       env_val  = keyval[:value].strip
       next if env_name.blank? && env_val.blank?
       if env_name !~ /^[A-Z][A-Z0-9_]+$/
         @tool_config.errors.add(:base, "Invalid environment variable name '#{env_name}'")
       elsif env_val !~ /\S/
         @tool_config.errors.add(:base, "Invalid blank variable value for '#{env_name}'")
       else
         @tool_config.env_array << [ env_name, env_val ]
       end
    end

    if @tool_config.tool_id && @tool_config.bourreau_id && @tool_config.description.blank?
      @tool_config.errors.add(:description, "requires at least one line of text as a name for the version")
    end

    @tool_config.group_id = Group.find_by_name("everyone") if @tool_config.group_id.blank?

    respond_to do |format|
      if @tool_config.errors.empty? && @tool_config.save
        flash[:notice] = "Tool configuration was successfully updated."
        format.html {
                    if @tool_config.tool_id
                      redirect_to edit_tool_path(@tool_config.tool)
                    else
                      redirect_to edit_bourreau_path(@tool_config.bourreau)
                    end
                    }
        format.xml  { head :ok }
      else        
        format.html { render :action => "edit" }
        format.xml  { render :xml => @tool_config.errors, :status => :unprocessable_entity }
      end
    end
  end

  def destroy #:nodoc:
    id = params[:id]
    @tool_config = ToolConfig.find(id)
    @tool_config.destroy

    flash[:notice] = "Tool configuration deleted."

    respond_to do |format|
      format.html { 
                    if @tool_config.tool_id
                      redirect_to edit_tool_path(@tool_config.tool)
                    else
                      redirect_to edit_bourreau_path(@tool_config.bourreau)
                    end
                  }
      format.xml  { head :ok }
    end
  end

end
