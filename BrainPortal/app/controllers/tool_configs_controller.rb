
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

# Controller for managing ToolConfig objects.
class ToolConfigsController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  before_filter :login_required
  before_filter :admin_role_required

  # Only accessible to the admin user.
  def index #:nodoc:

    @view ||= ((params[:view] || "") =~ /(by_bourreau|by_user|by_tool)/) ?
               Regexp.last_match[1] : nil

    if params[:user_id].blank? || params[:user_id].to_s !~ /^\d+$/
      @users       = User.all
    else
      @users       = [ User.find(params[:user_id].to_s) ]
      @view      ||= 'by_user'
    end

    if params[:bourreau_id].blank? || params[:bourreau_id].to_s !~ /^\d+$/
      @bourreaux   = Bourreau.all.select { |b| b.can_be_accessed_by?(current_user) }
    else
      @bourreaux   = [ Bourreau.find(params[:bourreau_id].to_s) ]
      @view      ||= 'by_bourreau'
    end

    if params[:tool_id].blank? || params[:tool_id].to_s !~ /^\d+$/
      @tools       = Tool.all
    else
      @tools       = [ Tool.find(params[:tool_id].to_s) ]
      @view      ||= 'by_tool'
    end

    @users     = @users.sort     { |a,b| a.login <=> b.login }
    @bourreaux = @bourreaux.sort { |a,b| a.name <=> b.name }
    @tools     = @tools.sort     { |a,b| a.name <=> b.name }

    # Limit the by_user report to at most 3 users...
    if @view == 'by_user' && @users.size > 3
      @users = @users[0..2]
    end
  end

  def show #:nodoc:
    id     = params[:id]
    config = ToolConfig.find(id)

    @tool_config          = config if   config.tool_id &&   config.bourreau_id # leaves nil otherwise
    @tool_glob_config     = config if   config.tool_id && ! config.bourreau_id # leaves nul otherwise
    @bourreau_glob_config = config if ! config.tool_id &&   config.bourreau_id # leaves nil otherwise

    @tool_glob_config     ||=
      ToolConfig.where( :tool_id => @tool_config.tool_id, :bourreau_id => nil                      ).first if @tool_config
    @bourreau_glob_config ||=
      ToolConfig.where( :tool_id => nil,                  :bourreau_id => @tool_config.bourreau_id ).first if @tool_config
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

    @tool_config   = ToolConfig.where( :tool_id => tool_id, :bourreau_id => bourreau_id ).first if tool_id.blank? || bourreau_id.blank?
    @tool_config ||= ToolConfig.new(   :tool_id => tool_id, :bourreau_id => bourreau_id )

    @tool_config.env_array ||= []

    @tool_config.group = Group.everyone

    respond_to do |format|
      format.html { render :action => :edit }
      format.xml  { render :xml => @tool_config }
    end
  end

  def edit #:nodoc:
    id           = params[:id]
    @tool_config = ToolConfig.find(id)
    @tool_config.env_array ||= []

    @tool_config.group = Group.everyone if @tool_config.group_id.blank?

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
    form_tool_id      = form_tool_config.tool_id.presence
    form_bourreau_id  = form_tool_config.bourreau_id.presence

    @tool_config   = nil
    @tool_config   = ToolConfig.find(id) unless id.blank?
    cb_error "Need at least one of tool ID or bourreau ID." if @tool_config.blank? && form_tool_id.blank? && form_bourreau_id.blank?
    @tool_config ||= ToolConfig.where( :tool_id => form_tool_id, :bourreau_id => form_bourreau_id ).first if form_tool_id.blank? || form_bourreau_id.blank?
    @tool_config ||= ToolConfig.new(   :tool_id => form_tool_id, :bourreau_id => form_bourreau_id )

    # Security: no matter what the form says, we use the ids from the DB if the object existed.
    form_tool_config.tool_id     = @tool_config.tool_id
    form_tool_config.bourreau_id = @tool_config.bourreau_id

    # Update everything else
    [ :version_name, :description, :script_prologue, :group_id, :ncpus, :docker_image, :extra_qsub_args ].each do |att|
       @tool_config[att] = form_tool_config[att]
    end

    @tool_config.env_array = []
    envlist = params[:env_list] || []
    envlist.each do |keyval|
       env_name = keyval[:name].strip
       env_val  = keyval[:value].strip
       next if env_name.blank? && env_val.blank?
       if env_name !~ /^[A-Z][A-Z0-9_]+$/i
         @tool_config.errors.add(:base, "Invalid environment variable name '#{env_name}'")
       elsif env_val !~ /\S/
         @tool_config.errors.add(:base, "Invalid blank variable value for '#{env_name}'")
       else
         @tool_config.env_array << [ env_name, env_val ]
       end
    end

    @tool_config.group = Group.everyone if @tool_config.group_id.blank?

    # Merge with an existing tool config
    if params.has_key?(:merge)
       other_tc = ToolConfig.find_by_id(params[:merge_from_tc_id] || 0)
       if other_tc
         if @tool_config.tool_id &&  @tool_config.bourreau_id
           @tool_config.description  = "#{@tool_config.description}\n#{other_tc.description}".strip
           @tool_config.version_name = other_tc.version_name
           @tool_config.group        = other_tc.group
           @tool_config.ncpus        = other_tc.ncpus
         end
         @tool_config.env_array       += (other_tc.env_array || [])
         @tool_config.script_prologue  = "#{@tool_config.script_prologue}\n#{other_tc.script_prologue}"
         flash[:notice] = "Appended info from another Tool Config."
       else
         flash[:notice] = "No changes made."
       end
       render :action => :edit
       return
    end

    if @tool_config.tool_id && @tool_config.bourreau_id && @tool_config.description.blank?
      @tool_config.errors.add(:description, "requires at least one line of text as a name for the version")
    end

    respond_to do |format|
      if @tool_config.save_with_logging(current_user, %w( env_array script_prologue ncpus ))
        flash[:notice] = "Tool configuration was successfully updated."
        format.html {
                    if @tool_config.tool_id
                      redirect_to edit_tool_path(@tool_config.tool)
                    else
                      redirect_to bourreau_path(@tool_config.bourreau)
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
                      redirect_to bourreau_path(@tool_config.bourreau)
                    end
                  }
      format.xml  { head :ok }
    end
  end

end
