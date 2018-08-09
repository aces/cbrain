
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

  api_available :only => [ :index, :show ]

  before_action :login_required
  before_action :admin_role_required, :except => [ :index ]

  def index #:nodoc:
    @scope = scope_from_session
    scope_default_order(@scope, 'name')

    @base_scope   = base_scope.includes([:tool, :bourreau, :group])
    @view_scope   = @scope.apply(@base_scope)

    @scope.pagination ||= Scope::Pagination.from_hash({ :per_page => 15 })
    @tool_configs = @scope.pagination.apply(@view_scope)

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
    id     = params[:id]
    @tool_config = ToolConfig.find(id)

    # @config.group = Group.everyone if @config.group_id.blank?

    @tool_config          = @tool_config
    @tool_local_config    = @tool_config if   @tool_config.tool_id && @tool_config.bourreau_id # leaves nul otherwise
    @tool_glob_config     = @tool_config if   @tool_config.tool_id && ! @tool_config.bourreau_id # leaves nul otherwise
    @bourreau_glob_config = @tool_config if ! @tool_config.tool_id &&   @tool_config.bourreau_id # leaves nil otherwise

    # @about_local_tool_config          = @tool_config.tool_id &&  @tool_config.bourreau_id
    # @about_tool_glob_config     = !!@tool_glob_config
    # @about_bourreau_glob_config = !!@bourreau_glob_config

    @tool_glob_config     ||=
      ToolConfig.where( :tool_id => @tool_config.tool_id, :bourreau_id => nil                      ).first if @tool_config
    @bourreau_glob_config ||=
      ToolConfig.where( :tool_id => nil,                  :bourreau_id => @tool_config.bourreau_id ).first if @tool_config


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
    tc_params         = tool_config_params
    form_tool_config  = ToolConfig.new(tc_params) # just to store the new attributes
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
    # or just form fields if config already existing
    [ :version_name, :description, :script_prologue, :group_id, :ncpus, :container_engine,
      :container_index_location, :containerhub_image_name, :container_image_userfile_id,
      :extra_qsub_args, :cloud_disk_image, :cloud_vm_user, :cloud_ssh_key_pair, :cloud_instance_type,
      :cloud_job_slots, :cloud_vm_boot_timeout, :cloud_vm_ssh_tunnel_port ].each do |att|
         if tc_params.has_key?(att) || id.blank?
           @tool_config[att] = form_tool_config[att]

         end
       end
       # not sure does conditional break any initialization rules

    if params.has_key?(:env_list) || id.blank?
      @tool_config.env_array = []
      envlist = params[:env_list] || []
      envlist.each do |keyval|
        env_name = keyval[:name].strip
        env_val  = keyval[:value].strip
        next if env_name.blank? && env_val.blank?
        if env_name !~ /\A[A-Z][A-Z0-9_]+\z/i
          @tool_config.errors.add(:base, "Invalid environment variable name '#{env_name}'")
        elsif env_val !~ /\S/
          @tool_config.errors.add(:base, "Invalid blank variable value for '#{env_name}'")
        else
          @tool_config.env_array << [ env_name, env_val ]
        end
      end
    end

    @tool_config.group = Group.everyone if @tool_config.group_id.blank?
    flash[:notice] = ""
    # Merge with an existing tool config
    if params.has_key?(:merge)
       other_tc = ToolConfig.find_by_id(params[:merge_from_tc_id] || 0)
       if other_tc
         if @tool_config.tool_id &&  @tool_config.bourreau_id
           @tool_config.description                 = "#{@tool_config.description}\n#{other_tc.description}".strip
           @tool_config.version_name                = other_tc.version_name
           @tool_config.group                       = other_tc.group
           @tool_config.ncpus                       = other_tc.ncpus
           @tool_config.container_engine            = other_tc.container_engine
           @tool_config.containerhub_image_name     = other_tc.containerhub_image_name
           @tool_config.container_image_userfile_id = other_tc.container_image_userfile_id
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
         flash[:notice] = "Appended info from another Tool Config."
       else
         flash[:notice] = "No changes made."
       end
       render :action => :show
       return
    end

    if @tool_config.tool_id && @tool_config.bourreau_id && @tool_config.description.blank?
      @tool_config.errors.add(:description, "requires at least one line of text as a name for the version")

    end

    respond_to do |format|
      if @tool_config.save_with_logging(current_user, %w( env_array script_prologue ncpus ))
        flash[:notice] ||= "Tool configuration was successfully updated."
        format.html {


          if id.present?
                      render :action => "show"
                        # redirect_to tool_config_path(@tool_config)
                      elsif  @tool_config.tool_id
                        redirect_to edit_tool_path(@tool_config.tool)
                      else
                        redirect_to bourreau_path(@tool_config.bourreau)
                      end
                    }
        format.xml  { head :ok }
      else
        format.html { render :action => "show" }
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

  private

  def tool_config_params #:nodoc:
    params.require(:tool_config).permit(
      :version_name, :description, :tool_id, :bourreau_id, :env_array, :script_prologue,
      :group_id, :ncpus, :container_image_userfile_id, :containerhub_image_name, :container_index_location,
      :container_engine, :extra_qsub_args,
      # The configuration of a tool in a VM managed by a
      # ScirCloud Bourreau is defined by the following
      # parameters which specify the disk image where the
      # tool is installed (including its ssh connection
      # properties) and the type of instance (thus RAM and
      # CPU requirements) to use.
      :cloud_disk_image, :cloud_vm_user, :cloud_ssh_key_pair, :cloud_instance_type,
      :cloud_job_slots, :cloud_vm_boot_timeout, :cloud_vm_ssh_tunnel_port
    )
  end

  # Create list of TC visible to current user.
  def base_scope #:nodoc:
    scope = ToolConfig.where(nil)
    unless current_user.has_role?(:admin_user)
      bourreau_ids = Bourreau.all.select { |b| b.can_be_accessed_by?(current_user) }.map(&:id)
      tool_ids     = Tool.all.select     { |t| t.can_be_accessed_by?(current_user) }.map(&:id)
      group_ids    = current_user.groups.raw_first_column(:id)
      scope = scope.where(
        :bourreau_id => bourreau_ids,
        :tool_id     => tool_ids,
        :group_id    => group_ids
      )
    end
    scope
  end

end
