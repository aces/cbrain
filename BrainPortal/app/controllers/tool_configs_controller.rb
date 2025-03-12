
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

  api_available :only => [ :index, :show, :boutiques_descriptor ]

  before_action :login_required,      :except => [ :boutiques_descriptor ]
  before_action :admin_role_required, :except => [ :index, :boutiques_descriptor ]

  def index #:nodoc:
    @scope = scope_from_session
    scope_default_order(@scope, 'name')

    @base_scope   = base_scope.includes([:tool, :bourreau, :group])
    @view_scope   = @scope.apply(@base_scope)

    @scope.pagination ||= Scope::Pagination.from_hash({ :per_page => 15 })
    @tool_configs = @scope.pagination.apply(@view_scope, api_request?)

    respond_to do |format|
      format.html
      format.json { render :json => @tool_configs.for_api }
      format.xml  { render :xml  => @tool_configs.for_api }
      format.js
    end
  end

  # Only accessible to the admin user.
  def report #:nodoc:

    @view ||= ((params[:view] || "") =~ /(by_bourreau|by_user|by_tool)/) ?
               Regexp.last_match[1] : nil

    if params[:user_id].blank? || params[:user_id].to_s !~ /\A\d+\z/
      @users       = User.all
    else
      @users       = [ User.find(params[:user_id].to_s) ]
      @view      ||= 'by_user'
    end

    if params[:bourreau_id].blank? || params[:bourreau_id].to_s !~ /\A\d+\z/
      @bourreaux   = Bourreau.all.select { |b| b.can_be_accessed_by?(current_user) }
    else
      @bourreaux   = [ Bourreau.find(params[:bourreau_id].to_s) ]
      @view      ||= 'by_bourreau'
    end

    if params[:tool_id].blank? || params[:tool_id].to_s !~ /\A\d+\z/
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
    id           = params[:id]
    @tool_config = ToolConfig.find(id)

    # Sets variables that are only used to show some info in about other
    # relevant TCs in the show/edit/create HTML page
    find_other_tool_configs()

    @tool_config.env_array ||= []

    respond_to do |format|
      format.html
      format.json { render :json => @tool_config.for_api }
    end
  end

  # The 'new' action is special in this controller.
  #
  # We need tool_id and bourreau_id as params; one or the other can be
  # nil but not both. A single potentially pre-existing object
  # will be accessed per pair of tool_id and bourreau_id when one of
  # them is nil. A brand new object is created when they are both
  # provided.
  def new
    tool_id     = params[:tool_id].presence     # nil allowed, means ALL tools
    bourreau_id = params[:bourreau_id].presence # nil allowed, means ALL remote resources
    cb_error "Need at least one of tool ID or bourreau ID." unless tool_id || bourreau_id

    # For shared configs, we check that the object is indeed new,
    # if not then show user existing object
    if tool_id.blank? || bourreau_id.blank?
      @tool_config = ToolConfig.where( :tool_id => tool_id, :bourreau_id => bourreau_id ).first
    end

    # If we haven't found an existing one of the globals, we create a new TC (either global
    # or specific)
    @tool_config ||= ToolConfig.new(   :tool_id => tool_id, :bourreau_id => bourreau_id )

    # Set a few defaults
    @tool_config.env_array ||= []
    @tool_config.group_id  ||= Group.everyone.id

    respond_to do |format|
      format.html { render :action => :show        }  # our show is also edit/create
      format.xml  { render :xml    => @tool_config }
    end
  end

  # This method is also used for the +create+ action.
  #
  # This method is special in that only one instance of
  # an object is permitted to exist for global ( per tool or per bourreau) config.
  # A global config object being created is first loaded from the DB if
  # it exists to prevent duplication.
  def update #:nodoc:
    id                = params[:id].presence # can be nil if we create() with tool_id and bourreau_id

    # What we get from the POST/PUT/PATCH
    tc_params         = tool_config_params

    form_tool_config  = ToolConfig.new(tc_params) # just to store the new attributes
    form_tool_id      = form_tool_config.tool_id.presence
    form_bourreau_id  = form_tool_config.bourreau_id.presence

    # Build the true object for the form
    @tool_config   = ToolConfig.find(id) unless id.blank?
    cb_error "Need at least one of tool ID or bourreau ID." if @tool_config.blank? && form_tool_id.blank? && form_bourreau_id.blank?
    @tool_config ||= ToolConfig.where( :tool_id => form_tool_id, :bourreau_id => form_bourreau_id ).first if form_tool_id.blank? || form_bourreau_id.blank?
    @tool_config ||= ToolConfig.new(   :tool_id => form_tool_id, :bourreau_id => form_bourreau_id )

    # Sets variables that are only used to show some info in about other
    # relevant TCs in the show/edit/create HTML page
    find_other_tool_configs()

    # Security: no matter what the form says, we use the ids from the DB if the object existed.
    form_tool_config.tool_id     = @tool_config.tool_id
    form_tool_config.bourreau_id = @tool_config.bourreau_id

    # Update everything else.
    # or just form fields if config already existing
    attributes = ToolConfig.column_names.map(&:to_sym) - %i[ id tool_id bourreau_id ]
    attributes.each do |att|
      if id.blank? || tc_params.has_key?(att) # we always copy everything if new
        @tool_config[att] = form_tool_config[att]
      end
    end
    @tool_config.group_id ||= Group.everyone.id

    # Copy environment variables, if any
    if params.has_key?(:env_list) || id.blank?
      @tool_config.env_array = []
      envlist = params[:env_list] || []
      envlist.each do |keyval|
        env_name = keyval[:name].strip
        env_val  = keyval[:value].strip
        next if env_name.blank? && env_val.blank?
        @tool_config.env_array << [ env_name, env_val ]
        if env_name !~ /\A[A-Z][A-Z0-9_]+\z/i
          @tool_config.errors.add(:base, "Invalid environment variable name '#{env_name}'")
        elsif env_val !~ /\S/
          @tool_config.errors.add(:base, "Invalid blank variable value for '#{env_name}'")
        end
      end
    end

    # Merge with an existing tool config
    # HTML only, always renders 'show'
    if params.has_key?(:merge)
       other_tc = ToolConfig.find_by_id(params[:merge_from_tc_id] || 0)
       if other_tc
         if @tool_config.tool_id &&  @tool_config.bourreau_id
           @tool_config.description                 = "#{@tool_config.description}\n#{other_tc.description}".strip
           @tool_config.version_name                = other_tc.version_name
           @tool_config.group                       = other_tc.group
           @tool_config.ncpus                       = other_tc.ncpus
           @tool_config.inputs_readonly             = other_tc.inputs_readonly
           @tool_config.container_engine            = other_tc.container_engine
           @tool_config.containerhub_image_name     = other_tc.containerhub_image_name
           @tool_config.container_image_userfile_id = other_tc.container_image_userfile_id
           @tool_config.container_exec_args         = other_tc.container_exec_args.presence
           @tool_config.container_index_location    = other_tc.container_index_location
           @tool_config.singularity_overlays_specs  = other_tc.singularity_overlays_specs
           @tool_config.extra_qsub_args             = other_tc.extra_qsub_args
           @tool_config.cloud_disk_image            = other_tc.cloud_disk_image
           @tool_config.cloud_vm_user               = other_tc.cloud_vm_user
           @tool_config.cloud_ssh_key_pair          = other_tc.cloud_ssh_key_pair
           @tool_config.cloud_instance_type         = other_tc.cloud_instance_type
           @tool_config.cloud_job_slots             = other_tc.cloud_job_slots
           @tool_config.cloud_vm_boot_timeout       = other_tc.cloud_vm_boot_timeout
           @tool_config.cloud_vm_ssh_tunnel_port    = other_tc.cloud_vm_ssh_tunnel_port
         end
         @tool_config.env_array       += (other_tc.env_array || [])
         @tool_config.script_prologue  = "#{@tool_config.script_prologue}\n#{other_tc.script_prologue}"
         @tool_config.script_epilogue  = "#{@tool_config.script_epilogue}\n#{other_tc.script_epilogue}"
         flash[:notice] = "Appended info from another Tool Config."
       else
         flash[:notice] = "No changes made."
       end

       render :action => "show"
       return
    end

    # Cancel a merge
    # HTML only, always renders 'show'
    if params.has_key?(:cancel)
      @tool_config.reload if ! @tool_config.new_record?
      render :action => "show"
      return
    end

    respond_to do |format|
      new_record = @tool_config.new_record?
      if @tool_config.save_with_logging(current_user,
         %w( version_name env_array script_prologue script_epilogue ncpus extra_qsub_args
             container_image_userfile_id containerhub_image_name
             container_engine container_index_location container_exec_args
             inputs_readonly
             singularity_overlays_specs singularity_use_short_workdir
             boutiques_descriptor_path
           )
        )

        if new_record
          flash[:notice] = "Tool configuration is successfully created."
        else
          flash[:notice] = "Tool configuration was successfully updated."
        end
        format.html { redirect_to tool_config_path(@tool_config) }
        format.xml  { head     :ok                                   }
      else
        format.html { render :action => :show } # @tool_config.reload  ? or may be just bad fields?
        format.json { render :json => @tool_config.errors, :status => :unprocessable_entity }
        format.xml  { render :xml  => @tool_config.errors, :status => :unprocessable_entity }
      end
    end
  end

  # The create and update methods are the same.
  alias_method :create, :update #:nodoc:

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

  # GET /tool_configs/:id/boutiques_descriptor[.json]
  def boutiques_descriptor
    id           = params[:id]
    @prettify    = params[:pretty].presence
    @prettify  &&= false if @prettify.to_s =~ /\A(0|false|nil)\z/i

    # Old fetch code restricted to user's permissions
    #@tool_config = base_scope.find(id)

    # New fetch code doesn't do any restriction
    @tool_config = ToolConfig.find(id)

    # Find the descriptor, if any
    @descriptor   = @tool_config.boutiques_descriptor # can be nil if not integrated with new BTQ
    @descriptor ||= BoutiquesSupport::BoutiquesDescriptor.new # empty otherwise
    @descriptor   = @descriptor.pretty_ordered if @prettify

    respond_to do |format|
      format.html
      format.json do
         render :json => JSON.pretty_generate(@descriptor) if ! @prettify
         render :json => @descriptor.super_pretty_json     if   @prettify
      end
    end
  end

  private

  def tool_config_params #:nodoc:
    params.require(:tool_config).permit(
      :version_name, :description, :tool_id, :bourreau_id, :env_array, :script_prologue, :script_epilogue,
      :group_id, :ncpus, :container_image_userfile_id, :containerhub_image_name, :container_index_location,
      :inputs_readonly,
      :container_engine, :extra_qsub_args, :singularity_overlays_specs, :container_exec_args,
      :singularity_use_short_workdir,
      :boutiques_descriptor_path
    )
  end


  # Create list of TC visible to current user.
  def base_scope #:nodoc:
    scope = ToolConfig.where(nil)
    unless current_user.has_role?(:admin_user)
      bourreau_ids = Bourreau.all.select { |b| b.can_be_accessed_by?(current_user) }.map(&:id)
      tool_ids     = Tool.all.select     { |t| t.can_be_accessed_by?(current_user) }.map(&:id)
      group_ids    = current_user.groups.ids
      scope = scope.where(
        :bourreau_id => bourreau_ids,
        :tool_id     => tool_ids,
        :group_id    => group_ids
      )
    end
    scope
  end

  # Given a @tool_config, finds other relevant objects and
  # returns them in instance variables. Used by views.
  def find_other_tool_configs #:nodoc:
    @tool_local_config    = @tool_config if   @tool_config.tool_id &&   @tool_config.bourreau_id # leaves nil otherwise
    @tool_glob_config     = @tool_config if   @tool_config.tool_id && ! @tool_config.bourreau_id # leaves nil otherwise
    @bourreau_glob_config = @tool_config if ! @tool_config.tool_id &&   @tool_config.bourreau_id # leaves nil otherwise

    @tool_glob_config     ||=
      ToolConfig.where( :tool_id => @tool_config.tool_id, :bourreau_id => nil                      ).first if @tool_config.tool_id
    @bourreau_glob_config ||=
      ToolConfig.where( :tool_id => nil,                  :bourreau_id => @tool_config.bourreau_id ).first if @tool_config.bourreau_id
  end

end

