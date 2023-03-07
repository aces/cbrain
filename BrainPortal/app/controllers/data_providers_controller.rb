
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

require 'file_info'

# Controller for the DataProvider resource.
class DataProvidersController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  api_available :only => [ :index, :show, :is_alive, :create_by_normal_user, :check,
                           :browse, :register, :unregister, :delete]

  before_action :login_required
  before_action :manager_role_required, :only => [:create]
  before_action :admin_role_required,   :only => [:report, :repair]

  def index #:nodoc:
    @scope = scope_from_session
    scope_default_order(@scope, 'name')

    @base_scope = DataProvider
      .find_all_accessible_by_user(current_user)
      .includes(:user, :group)
    @data_providers = @scope.apply(@base_scope)

    respond_to do |format|
      format.html
      format.xml  do
        render :xml  => @data_providers.for_api
      end
      format.json do
        render :json => @data_providers.for_api
      end
      format.js
    end
  end

  # GET /data_providers/1
  # GET /data_providers/1.xml
  # GET /data_providers/1.json
  def show  #:nodoc:
    data_provider_id = params[:id]
    @provider        = DataProvider.find(data_provider_id)

    cb_notice "Provider not accessible by current user." unless @provider.can_be_accessed_by?(current_user)

    respond_to do |format|
      format.html # show.html.erb
      format.xml  {
        render :xml  => @provider.for_api
      }
      format.json {
        render :json => @provider.for_api
      }
    end
  end

  def new #:nodoc:
    provider_group_id = current_assignable_group.id
    @provider = DataProvider.new( :user_id   => current_user.id,
                                  :group_id  => provider_group_id,
                                  :online    => true,
                                  :read_only => false
                                )

    @typelist = get_type_list
    @groups   = current_user.assignable_groups | current_user.listable_groups #
    render template: 'data_providers/normal_new' unless current_user.has_role?(:admin_user) # normal user only allowed create UserkeyFlatDirSshDataProvider
  end

  def create # for manager dp create (much more features than normal user create)
    @provider            = DataProvider.sti_new(data_provider_params)
    @provider.user_id  ||= current_user.id # disabled field in form DOES NOT send value!
    @provider.group_id ||= current_assignable_group.id

    if @provider.save
      add_meta_data_from_form(@provider, [:must_move, :no_uploads, :no_viewers, :browse_gid])
      @provider.addlog_context(self,"Created by #{current_user.login}")
      flash[:notice] = "Provider successfully created."
      respond_to do |format|
        format.html { redirect_to :action => :index, :format => :html}
        format.xml  { render :xml   => @provider }
        format.json { render :json  => @provider }
      end
    else
      @typelist = get_type_list
      respond_to do |format|
        format.html { render :action => :new }
        format.xml  { render :xml  => @provider.errors, :status => :unprocessable_entity }
        format.json { render :json => @provider.errors, :status => :unprocessable_entity }
      end
    end
  end

  # dp creation by normal user, currently only UserkeyFlatDirSshDataProvider
  # allow user create his own data providers.  At the moment only ssh with UserkeyFlatDirSshDataProvider and few field only
  def create_by_normal_user

    normal_params = params.require_as_params(:data_provider)
                        .permit(:name, :description, :group_id,
                                :remote_user, :remote_host,
                                :remote_port, :remote_dir
                                )
    group_id = normal_params[:date_provider][:group_id]
    Group.where(id: current_user.assignable_group_ids).find(group_id) # ensure assignable, not sure need check visibility etc more
    @provider = UserkeyFlatDirSshDataProvider.new(normal_params)
    @provider.update_attributes(
      :user_id => current_user.id
    )
    if @provider.save
      @provider.addlog_context(self, "Created by #{current_user.login}")
      @provider.meta[:browse_gid] = current_user.own_group.id
      respond_to do |format|
        format.html { redirect_to :action => :index, :format => :html }
        format.xml  { render      :xml    => @provider }
        format.json { render      :json   => @provider }
      end
    else
      respond_to do |format|
        format.html { render :action => :new_normal }
        format.xml  { render :xml    => @provider.errors,  :status => :unprocessable_entity }
        format.json { render :json   => @provider.errors,  :status => :unprocessable_entity }
      end
    end
  end

  def update #:nodoc:
    @user     = current_user
    id        = params[:id]
    @provider = DataProvider.find(id)

    unless @provider.has_owner_access?(current_user)
       flash[:error] = "You cannot edit a provider that you do not own."
       respond_to do |format|
        format.html { redirect_to :action => :show }
        format.xml  { head :forbidden }
        format.json { head :forbidden }
       end
       return
    end

    Group.where(id: current_user.assignable_group_ids).find(group_id) if ! current_user.has_role?(:admin_user)
    # regular, aka normal, users can change group, but only to ones (s)he see and allowed assign to

    new_data_provider_attr = data_provider_params
    new_data_provider_attr.delete :type # Type cannot be updated once it is set.

    # Fields that stay the same if the form provides a blank entry:
    new_data_provider_attr.delete :cloud_storage_client_token if new_data_provider_attr[:cloud_storage_client_token].blank?

    if @provider.update_attributes_with_logging(new_data_provider_attr, current_user,
         %w(
           remote_user remote_host remote_port remote_dir
           not_syncable cloud_storage_client_identifier cloud_storage_client_token
           cloud_storage_client_bucket_name cloud_storage_client_path_start
           cloud_storage_endpoint cloud_storage_region
           datalad_repository_url datalad_relative_path
           containerized_path
         )
      )
      meta_flags_for_restrictions = (params[:meta] || {}).keys.grep(/\Adp_no_copy_\d+\z|\Arr_no_sync_\d+\z/)
      add_meta_data_from_form(@provider, [:must_move, :no_uploads, :no_viewers, :browse_gid] + meta_flags_for_restrictions)
      flash[:notice] = "Provider successfully updated."
      respond_to do |format|
        format.html { redirect_to :action => :show }
        # remove? for some reason api is disabled on update
        format.xml  { render      :xml    =>  @provider }
        format.json { render      :json   =>  @provider }
      end
    else
      @provider.reload
      respond_to do |format|
        format.html { render :action => 'show' }
        format.xml  { render :xml    => @provider.errors, :status  => :unprocessable_entity }
        format.json { render :json   => @provider.errors, :status  => :unprocessable_entity }
      end
    end
  end

  def destroy #:nodoc:
    @data_provider  = DataProvider.find_accessible_by_user(params[:id], current_user)

    unless @data_provider.has_owner_access?(current_user)
      raise CbrainDeleteRestrictionError.new("You cannot remove a provider that you do not own.")
    end

    @data_provider.destroy

    flash[:notice] = "Provider successfully deleted."

    respond_to do |format|
      format.html { redirect_to :action => :index }
      format.js   { redirect_to :action => :index, :format => :js } # no longer used?
      format.xml  { head :ok }
      format.json { head :ok }
    end
  rescue ActiveRecord::DeleteRestrictionError => e
    flash[:error] = "Provider not destroyed: #{e.message}"

    respond_to do |format|
      format.html { redirect_to :action => :index }
      format.js   { redirect_to :action => :index, :format => :js } # no longer used?
      format.xml  { head :conflict }
      format.json { head :conflict }
    end
  end

  # Returns information about the aliveness of +dataprovider+. First checks if a result for this
  #+dataprovider+ has been cached, if not it checks directly and updates the cache
  def is_alive
    @provider = DataProvider.find_accessible_by_user(params[:id], current_user)

    is_alive = @provider.is_alive_with_caching?

    respond_to do |format|
      format.html { render :html => red_if( ! is_alive, "<span>Yes</span>".html_safe, "No" ) }
      format.xml  { render :xml  => { :is_alive => is_alive } }
      format.json { render :json => { :is_alive => is_alive } }
    end
  end

  # Returns a report about the +dataprovider+ disk usage by users.
  def disk_usage
    dataprovider_id = params[:id]       || ""
    user_ids        = params[:user_ids] || nil

    available_users = current_user.available_users
    user_ids        = user_ids ? available_users.where(:id => user_ids).raw_first_column(:id) :
                                 available_users.raw_first_column(:id)

    raise "Bad params"              if dataprovider_id.blank? || user_ids.blank?
    dataprovider    = DataProvider.find(dataprovider_id.to_i)
    raise "Bad params"              if !dataprovider.can_be_accessed_by?(current_user)

    base_relation = Userfile.where(:user_id => user_ids).where(:data_provider_id => dataprovider_id)

    # Create a hash table with information grouped by user.
    info_by_user = {}
    user_ids.each do |user_id|
      user_relation   = base_relation.where(:user_id => user_id)

      number_entries  = user_relation.count
      total_size      = user_relation.sum(:size)
      number_files    = user_relation.sum(:num_files)
      number_unknown  = user_relation.where("size is null").count

      # If we want to filter empty entries
      # next if number_entries == 0 && total_size == 0 && number_files == 0 && number_unknown == 0

      info_by_user[user_id] = {}
      info_by_user[user_id][:number_entries]  =  number_entries.to_i
      info_by_user[user_id][:total_size]      =  total_size.to_i
      info_by_user[user_id][:number_files]    =  number_files.to_i
      info_by_user[user_id][:number_unknown]  =  number_unknown.to_i
    end

    respond_to do |format|
      format.html { render :plain => info_by_user.inspect } # not really html
      format.xml  { render :xml   => info_by_user }
      format.json { render :json  => info_by_user }
    end

  rescue
    respond_to do |format|
      format.html { render :html => '<strong style="color:red">No Information Available</strong>'.html_safe }
      format.xml  { head :unprocessable_entity }
      format.json { head :unprocessable_entity }
    end

  end

  # Generates a report about which data providers the current user has access to.
  def dp_access
    @providers = DataProvider.find_all_accessible_by_user(current_user).all.sort do |a,b|
                   (b.online?.to_s       <=> a.online?.to_s).nonzero?       ||
                   (a.is_browsable?.to_s <=> b.is_browsable?.to_s).nonzero? ||
                   (a.name               <=> b.name)
                 end
    @users     = current_user.available_users.all.sort do |a,b|
                   (a.account_locked?.to_s <=> b.account_locked?.to_s) ||
                   (a.login                <=> b.login)
                 end
  end

  # Generates a table report about which data provider is allowed to send data to
  # which other data provider.
  def dp_transfers
    @providers = DataProvider.find_all_accessible_by_user(current_user).all.sort do |a,b|
                   (b.online?.to_s       <=> a.online?.to_s).nonzero?       ||
                   (a.is_browsable?.to_s <=> b.is_browsable?.to_s).nonzero? ||
                   (a.name               <=> b.name)
                 end
  end

  # Browse the files of a data provider.
  # This action is only available for data providers that are browsable.
  # Both registered and unregistered files will appear in the list.
  def browse
    @provider = DataProvider.find_accessible_by_user(params[:id], current_user)

    unless @provider.is_browsable?(current_user) && @provider.online?
      flash[:error]  = "You cannot browse Data Provider '#{@provider.name}'.\n"
      flash[:error] += "It is currently marked as 'offline'." if ! @provider.online
      respond_to do |format|
        format.html { redirect_to :action => :index }
        format.xml  { render :xml  => { :error => flash[:error] }, :status => :forbidden }
        format.json { render :json => { :error => flash[:error] }, :status => :forbidden }
      end
      return
    end

    # Load up the default scope for DP browsing and handle 'name_like'.
    @scope = scope_from_session(browse_scope_name(@provider))
    scope_filter_from_params(@scope, :name_like, {
      :attribute => 'name',
      :operator  => 'match'
    })

    # Browsing as a different user? Make sure the target user is set.
    @as_user = browse_as(@provider, params['as_user_id'])
    @scope.custom['as_user_id'] = @as_user.id # can also be current user

    # Browsing under a different path? Validate that.
    # This browse path is always nil for data provider classes that
    # do not support the capability. For those that do, the browse path
    # can also be nil when browsing at the top of the DP. Otherwise it's
    # a relative path "a/b/c"
    @browse_path = current_browse_path(@provider, params['browse_path'])
    @scope.custom['browse_path'] = @browse_path

    begin
      # [ base, size, type, mtime ]
      @fileinfolist = BrowseProviderFileCaching.get_recent_provider_list_all(@provider, @as_user, @browse_path, params[:refresh])
    rescue => e
      flash[:error] = 'Cannot get list of files. Maybe the remote directory doesn\'t exist or is locked?' #emacs fails to parse this properly so I switched to single quotes.
      Message.send_internal_error_message(User.find_by_login('admin'), "Browse DP exception", e, params) rescue nil
      respond_to do |format|
        format.html { redirect_to :action => :index }
        format.xml  { render :xml   => flash[:error], :status  => :unprocessable_entity}
        format.json { render :json  => flash[:error], :status  => :unprocessable_entity}
      end
      return
    end

    # Make a list of files that are already registered on this DP.
    registered_files = Userfile.where( :data_provider_id => @provider.id )
    # On data providers where files are stored in a per user subdir, we limit our
    # search of what's registered to only those belonging to @as_user;
    # otherwise we must report when files are registered by other users too.
    registered_files = registered_files.where( :user_id => @as_user.id ) if ! @provider.content_storage_shared_between_users?

    # On data providers where files are stored along with a browse_path (a remote
    # relative path 'under' the DP's configured root), we must consider only
    # the files with the same browse_path. Files with the same basename but in
    # a different browse_path are considered distinct. (Note: One day users will create
    # hard links and everthing will be messed up)
    registered_files = registered_files.where( :browse_path => @browse_path ) if @provider.has_browse_path_capabilities?

    # Add attributes and cross-reference with previously registered files
    # - Adds: the userfile and userfile_id if the file is already registered
    FileInfo.array_match_all_userfiles(@fileinfolist, registered_files)
    # Check filenames, check for type inconsistencies
    # - Adds: the state_ok flag that tell whether or not it's OK to register/unregister
    # - Adds: an error message if something is wrong
    FileInfo.array_validate_for_registration(@fileinfolist)

    # Now that @fileinfolist is complete, apply @scope's elements and paginate
    # before display.
    @fileinfolist = @scope.apply(@fileinfolist)

    @scope.pagination ||= Scope::Pagination.from_hash({ :per_page => 25 })
    @files = @scope.pagination.apply(@fileinfolist)

    scope_to_session(@scope)

    respond_to do |format|
      format.html
      format.xml do
        @fileinfolist.each do |fil| # just setting userfile to nil breaks the schema, it must be unset
          fil.instance_eval { remove_instance_variable :@userfile } rescue nil
        end
        render :xml  => @fileinfolist
      end
      format.json do
        @fileinfolist.each do |fil| # just setting userfile to nil breaks the schema, it must be unset
          fil.instance_eval { remove_instance_variable :@userfile } rescue nil
        end
        render :json  => @fileinfolist
      end
      format.js
    end

  end

  # Register a list of files (+basenames+) into CBRAIN from a given data
  # provider (parameter +id+), with types +filetypes+ under group +group_id+.
  # An optional action can be taken once registration is complete; if +auto_do+
  # is 'COPY' or 'MOVE', the newly registered files will be copied (or moved)
  # to the given alternate data provider +other_data_provider_id+. If the
  # special parameter +as_user_id+ is given, the files will be registered
  # under that user instead of the current user. Note that registration
  # happens in background for HTML & JS requests.
  def register
    # Extract key parameters & make sure the provider is browsable
    @provider    = DataProvider.find_accessible_by_user(params[:id], current_user)
    @as_user     = browse_as(@provider, params['as_user_id'])
    @browse_path = current_browse_path(@provider, params['browse_path'])
    unless @provider.is_browsable?(current_user)
      flash[:error] = "You cannot register files from this provider."
      respond_to do |format|
        format.html { redirect_to :action => :index }
        format.xml  { render :xml  => { :error => flash[:error] }, :status => :forbidden }
        format.json { render :json => { :error => flash[:error] }, :status => :forbidden }
      end
      return
    end

    flash[:notice] ||= ''

    # Is there an automatic copy/move operation to do afterwards?
    post_action = :copy if params[:auto_do] == "COPY"
    post_action = :move if params[:auto_do] == "MOVE"
    target_dp   = DataProvider.find_accessible_by_user(params[:other_data_provider_id], current_user) rescue nil
    if post_action && ! target_dp
      flash[:error] = "Missing destination data provider for copy or move."
      respond_to do |format|
        format.html { redirect_to :action => :browse }
        format.xml  { render :xml  => { :error => flash[:error] }, :status => :unprocessable_entity }
        format.json { render :json => { :error => flash[:error] }, :status => :unprocessable_entity }
      end
      return
    end

    # Provided file types for the file(s) to register. If a file is present
    # in 'basenames' (to be registered) but *not* in 'filetypes', a default
    # of 'SingleFile' is used.
    filetypes = Array(params[:filetypes])
      .map { |v| [$2, $1] if v.match(/\A(\w+)-(\S+)\z/) }
      .compact
      .to_h

    # Known userfile types, used to validate the values extracted above
    valid_types = Userfile.descendants
      .map(&:name)

    # The new file(s)'s default project is the currently active project, if
    # available.
    group_id = current_assignable_group.id

    # Unless one was specified explicitly via :other_group_id
    group_id = params[:other_group_id].to_i unless
      params[:other_group_id].blank?

    # Fallback to the user's own project if the one selected above is invalid
    # (the everyone project, under which no file is ever registered, or a
    # project the user doesn't have access to).
    group_id = current_user.own_group.id unless
      current_user.assignable_group_ids.include?(group_id)

    # Remind the user if browsing as another user
    flash[:notice] += "Important note! Since you were browsing as user '#{@as_user.login}', the files will be registered as belonging to that user instead of you!\n" if
      @as_user != current_user

    # Register the given userfiles in background.
    userfiles = userfiles_from_basenames(@provider, @as_user, params[:basenames], @browse_path)
    userfiles_count = userfiles.count # Avoids a cute race condition

    registered, already_registered = [], []
    succeeded, failed = [], {}

    CBRAIN.spawn_with_active_records_if(
      [:html, :js].include?(request.format.to_sym),
      current_user,
      "Register files DP=#{@provider.id}"
    ) do
      userfiles.keys.shuffle.each_with_index_and_size do |basename,idx,size|
        Process.setproctitle "Register DP=#{@provider.id} NAME=#{basename} #{idx+1}/#{size}"
        begin
          # Is the file already registered?
          if userfiles[basename].present?
            already_registered << userfiles[basename]
            (failed["Already registered"] ||= []) << basename
            next
          end

          # Determine the filetype of the new file
          subtype = filetypes[basename] || "SingleFile"
          unless valid_types.include?(subtype)
            (failed["Unknown type #{subtype}"] ||= []) << basename
            next
          end

          # Create the new userfile
          userfile = subtype.constantize.new(
            :name             => basename,
            :user_id          => @as_user.id,
            :group_id         => group_id,
            :data_provider_id => @provider.id,
            :browse_path      => @browse_path, # nil => top, or nil => N/A, depends on DP
          )

          # And save it
          if userfile.save
            userfile.addlog_context(self, "Registered on DataProvider '#{@provider.name}' as '#{userfile.browse_name}' by #{current_user.login}.")
            registered << (userfiles[basename] = userfile)
            succeeded << basename
          else
            (failed["Unspecified error"] ||= []) << "#{userfile.name} : #{userfile.errors.full_messages.join(", ")}"
          end

        rescue => e
          (failed[e.message] ||= []) << basename
        end
      end

      # If files actually got registered, clear the browsing cache
      BrowseProviderFileCaching.clear_cache(@provider, @as_user, @browse_path) if
        succeeded.present? && [:html, :js].include?(request.format.to_sym)

      # No need to move or copy? Just set the file sizes and exit.
      unless post_action
        registered.each_with_index_and_size do |userfile,idx,size|
          Process.setproctitle "SetSize ID=#{userfile.id} #{idx+1}/#{size}      "
          userfile.set_size rescue true
        end
        generic_notice_messages('register', succeeded, failed)
        next
      end

      # Notify user of registration successes and failures.
      generic_notice_messages('register', succeeded, failed,
        "Files will now be #{post_action == :move ? 'moved' : 'copied'} in background.")

      # Prepare to copy/move the files to the new DP
      succeeded, failed = [], {}

      # Will some of the file names collide?
      collisions = Userfile
        .where(
          :name             => registered.map(&:name),
          :user_id          => @as_user.id,
          :data_provider_id => target_dp.id
        )
        .pluck('userfiles.name')

      userfiles = registered.reject { |r| collisions.include?(r.name) }
      if collisions.present?
        failed["Filename collision"] ||= []
        failed["Filename collision"]  += collisions
      end

      # Copy/move each file
      userfiles.shuffle.each_with_index do |userfile, ix|
        Process.setproctitle "#{post_action.to_s.humanize} registered files ID=#{userfile.id} #{ix + 1}/#{userfiles.size}"

        begin
          case post_action
          when :move
            userfile.provider_move_to_otherprovider(target_dp)

          when :copy
            new = userfile.provider_copy_to_otherprovider(target_dp)
            userfile.delete rescue true # Not destroy(), as the contents must be kept.
            userfile.destroy_log rescue true
            userfile = new
          end

          userfile.set_size!
          succeeded << userfile
        rescue => e
          (failed[e.message] ||= []) << userfile
        end
      end

      mangled_action = (post_action == :move ? 'mov' : 'copy') # most work with 'ing' appended
      generic_notice_messages(mangled_action, succeeded, failed)
    end

    # Generate a complete response matching the old API
    flash[:notice] += "Registering #{userfiles_count} userfile(s) in background.\n"
    api_response = generate_register_response.merge({
      :newly_registered_userfiles      => registered.for_api,
      :previously_registered_userfiles => already_registered.for_api,
    })

    respond_to do |format|
      format.html { redirect_to :action => :browse }
      format.xml  { render :xml  => api_response }
      format.json { render :json => api_response }
    end
  end

  # Unregister (and optionally delete) a list of files (+basenames+) from a given
  # CBRAIN data provider (parameter +id+). This action accepts 2 optional parameters;
  # +as_user_id+ to unregister as a given user rather than as the current user, and
  # +delete+, if files are to be deleted once unregistered.
  # Note that unregistration will happen in background for HTML & JS requests.
  def unregister
    # Extract key parameters & make sure the provider is browsable
    @provider    = DataProvider.find_accessible_by_user(params[:id], current_user)
    @as_user     = browse_as(@provider, params['as_user_id'])
    @browse_path = current_browse_path(@provider, params['browse_path'])
    unless @provider.is_browsable?(current_user)
      flash[:error] = "You cannot unregister files from this provider."
      respond_to do |format|
        format.html { redirect_to :action => :index }
        format.xml  { render :xml  => { :error => flash[:error] }, :status => :forbidden }
        format.json { render :json => { :error => flash[:error] }, :status => :forbidden }
      end
      return
    end

    flash[:notice] ||= ''

    # Unregister the given userfiles in background.
    userfiles = userfiles_from_basenames(@provider, @as_user, params[:basenames], @browse_path)
    succeeded, failed = [], {}
    erasing = params[:delete].present?

    CBRAIN.spawn_with_active_records_if(
      [:html, :js].include?(request.format.to_sym),
      current_user,
      "Unregister files DP=#{@provider.id}"
    ) do
      userfiles.reject { |b,u| u.blank? }.to_a.shuffle.each_with_index_and_size do |base_uf,idx,size|
        basename, userfile = *base_uf  # pair of values
        Process.setproctitle "Unregister DP=#{@provider.id} ID=#{userfile.id} #{idx+1}/#{size}"
        begin
          # Make sure the current user can unregister the file
          unless userfile.has_owner_access?(current_user)
            (failed["Insufficient permissions"] ||= []) << basename
            next
          end

          # Userfile.delete will not delete the contents, but destroy will
          if erasing
            result = userfile.destroy
          else
            # Since the .delete operation doesn't trigger callbacks,
            # we invoke the resource tracker method explicitely
            userfile.send :track_resource_usage_destroy # private method
            result = userfile.delete
          end
          userfile.destroy_all_meta_data rescue true
          userfile.destroy_log           rescue true

          (result ? succeeded : (failed["Unspecified error"] ||= [])) << basename
        rescue => e
          (failed[e.message] ||= []) << basename
        end
      end

      # If files actually got erased, clear the browsing cache
      BrowseProviderFileCaching.clear_cache(@provider, @as_user, @browse_path) if
        erasing && succeeded.present? && [:html, :js].include?(request.format.to_sym)

      generic_notice_messages('unregister', succeeded, failed)
    end

    # Generate a complete response matching the old API
    flash[:notice] += "Unregistering #{userfiles.size} userfile(s) in background.\n"

    api_response = generate_register_response
    api_response[erasing ? :num_erased : :num_unregistered] = succeeded.size

    respond_to do |format|
      format.html { redirect_to :action => :browse }
      format.xml  { render :xml  => api_response }
      format.json { render :json => api_response }
    end
  end

  # Delete a list of files (+basenames+) from a given CBRAIN data provider
  # (parameter +id+). This action differs from +unregister+ (with +delete+
  # option) by not requiring the files to be registered in CBRAIN. As with
  # +register+ and +unregister+, a +as_user_id+ parameter is supported and
  # the deletion occurs in background.
  def delete
    # Extract key parameters & make sure the provider is browsable
    @provider    = DataProvider.find_accessible_by_user(params[:id], current_user)
    @as_user     = browse_as(@provider, params['as_user_id'])
    @browse_path = current_browse_path(@provider, params['browse_path'])
    unless @provider.is_browsable?(current_user)
      flash[:error] = "You cannot delete files from this provider."
      respond_to do |format|
        format.html { redirect_to :action => :index }
        format.xml  { render :xml  => { :error => flash[:error] }, :status => :forbidden }
        format.json { render :json => { :error => flash[:error] }, :status => :forbidden }
      end
      return
    end

    flash[:notice] ||= ''

    # Erase the given userfiles in background.
    userfiles = userfiles_from_basenames(@provider, @as_user, params[:basenames], @browse_path)
    succeeded, failed = [], {}

    CBRAIN.spawn_with_active_records_if(
      [:html, :js].include?(request.format.to_sym),
      current_user,
      "Delete files DP=#{@provider.id}"
    ) do
      userfiles.to_a.shuffle.each_with_index_and_size do |base_uf,idx,size|
        basename, userfile = *base_uf  # pair of values
        label = userfile.present? ? "ID=#{userfile.id}" : "NAME=#{basename}"
        Process.setproctitle "Delete DP=#{@provider.id} #{label} #{idx+1}/#{size}"
        begin
          # Is the userfile registered?
          if userfile.present?
            # Make sure the current user can delete the file
            unless userfile.has_owner_access?(current_user)
              (failed["Insufficient permissions"] ||= []) << basename
              next
            end

            result = userfile.destroy

          # Otherwise, create a temporary userfile for provider_erase
          else
            # FileCollection's deletion handling should support both regular files and directories
            temporary = FileCollection.new(
              :name          => basename,
              :data_provider => @provider,
              :user_id       => @as_user.id,
              :browse_path   => @browse_path,
              :group_id      => current_user.own_group.id
            ).fake_record!

            result = @provider.provider_erase(temporary)
          end

          (result ? succeeded : (failed["Unspecified error"] ||= [])) << basename
        rescue => e
          (failed[e.message] ||= []) << basename
        end
      end

      # If files actually got erased, clear the browsing cache
      BrowseProviderFileCaching.clear_cache(@provider, @as_user, @browse_path) if
        succeeded.present? && [:html, :js].include?(request.format.to_sym)

      generic_notice_messages('delet', succeeded, failed)
    end

    # Generate a complete response matching the old API
    flash[:notice] += "Deleting #{userfiles.count} userfile(s) in background.\n"
    api_response = generate_register_response.merge({
      :num_erased => succeeded.size
    })

    respond_to do |format|
      format.html { redirect_to :action => :browse }
      format.xml  { render :xml  => api_response }
      format.json { render :json => api_response }
    end
  end

  # Report inconsistencies in the data provider.
  def report
    @scope    = scope_from_session
    @provider = DataProvider.find(params[:id])
    @issues   = @provider.provider_report(params[:reload]) || []

    scope_default_order(@scope, :severity)
    @scope.pagination ||= Scope::Pagination.from_hash({ :per_page => 25 })
    @view_scope = @scope.apply(@issues, paginate: true)

    respond_to do |format|
      # Avoid to reload the page when switching page
      if params[:reload]
        format.html { redirect_to :action => :report }
      else
        format.html
      end
      format.js
      format.xml  { render :xml  => { :issues => @issues } }
      format.json { render :json => { :issues => @issues } }
    end
  end

  # Repair one or more inconsistencies in the data provider.
  def repair
    @provider = DataProvider.find(params[:id])
    @issues   = @provider.provider_report.select { |i| params[:issue_ids].include? i[:id].to_s }

    if @issues.blank?
      respond_to do |format|
        format.html { redirect_to :action => :report }
      end
      return
    end

    Message.send_message(current_user,
      :message_type  => :notice,
      :header        => "Repair #{@issues.size} inconsistencies in background.",
    )

    CBRAIN.spawn_with_active_records(:admin, "Repair DP #{@provider.name}") do
      # Try to repair the inconsistencies (or issues)
      failed_list  = []
      success_list = []

      @issues.each_with_index_and_size do |issue, idx, size|
        Process.setproctitle "Repair ID=#{@provider.id} #{idx+1}/#{size}"
        begin
          @provider.provider_repair(issue)
          success_list << issue
        rescue => ex
          failed_list  << [issue, ex]
        end
      end

      # Display a message reporting how many issues were repaired
      if failed_list.empty?
        Message.send_message(current_user,
          :message_type  => :notice,
          :header        => "#{@issues.size} issue(s) repaired successfully.",
          :variable_text => success_list.map do |issue|
            line  = ["|#{issue[:message]}|: repaired"]
            line << " (action taken: #{issue[:action].to_s.titleize})" if issue[:action]
            line << "\n"
            line.join
          end.join
        )
      else
        Message.send_message(current_user,
          :message_type  => :error,
          :header        => "Out of #{@issues.size} issue(s), #{failed_list.size} could not be repaired:",
          :variable_text => "Report:\n" + failed_list.map { |issue,ex| "|#{issue[:message]}|: #{ex.message}" }.join("\n")
        )
      end
    end

    respond_to do |format|
      format.html { redirect_to :action => :report }
    end
  end

  # This action checks that the remote side of a Ssh DataProvider is
  # accessible using SSH.
  def check

    id = params[:id]
    @provider = DataProvider.find(id)
    unless @provider.has_owner_access?(current_user)
      flash[:error] = "You cannot check a provider that you do not own."
      respond_to do |format|
        format.html { redirect_to :action => :show }
        format.xml  { head        :forbidden }
        format.json { head        :forbidden }
      end
      return
    end

    id = params[:id]
    @provider = DataProvider.find(id)
    unless @provider.is_a? SshDataProvider
      flash[:error] = "Presently, detailed check is only available to ssh providers."
      respond_to do |format|
        format.html { redirect_to :action => :show }
        format.xml  { head        :forbidden }
        format.json { head        :forbidden }
      end
      return
    end

    # todo perhaps move most to the model

    master = @provider.master # This is a handler for the connection, not persistent.
    tmpfile = "/tmp/dp_check.#{Process.pid}.#{rand(1000000)}"

    # Check #1: the SSH connection can be established
    if !master.is_alive?
      test_error "Cannot establish the SSH connection. Check the configuration: username, hostname, port are valid, and SSH key is installed."
    end

    # Check #2: we can run "true" on the remote site and get no output
    status = master.remote_shell_command_reader("true",
                                                :stdin  => "/dev/null",
                                                :stdout => "#{tmpfile}.out",
                                                :stderr => "#{tmpfile}.err"
    )
    stdout = File.read("#{tmpfile}.out") rescue "Error capturing stdout"
    stderr = File.read("#{tmpfile}.err") rescue "Error capturing stderr"
    if stdout.size != 0
      stdout.strip! if stdout.present? # just to make it pretty while still reporting whitespace-only strings
      test_error "Remote shell is not clean: got some bytes on stdout: '#{stdout}'"
    end
    if stderr.size != 0
      stderr.strip! if stdout.present?
      test_error "Remote shell is not clean: got some bytes on stderr: '#{stderr}'"
    end
    if !status
      test_error "Got non-zero return code when trying to run 'true' on remote side."
    end

    # Check #3: the remote directory exists
    master.remote_shell_command_reader "test -d #{@provider.remote_dir.bash_escape} && echo DIR-OK", :stdout => tmpfile
    out = File.read(tmpfile)
    if out != "DIR-OK\n"
      test_error "The remote directory doesn't seem to exist."
    end

    # Check #4: the remote directory is readable
    master.remote_shell_command_reader "test -r #{@provider.remote_dir.bash_escape} && test -x #{@provider.remote_dir.bash_escape} && echo DIR-READ", :stdout => tmpfile
    out = File.read(tmpfile)
    if out != "DIR-READ\n"
      test_error "The remote directory doesn't seem to be readable"
    end
    @provider.update_column(:online, true)
    # Ok, all is well.
    flash[:notice] = "The configuration was tested and seems to be operational."
    respond_to do |format|
      format.html do
        redirect_to :action => :show
      end
      format.xml  do
        render :xml  => 'ok'
      end
      format.json do
        render :json => 'ok'
      end
    end


  rescue UserKeyTestConnectionError => ex
    flash[:error]  = ex.message
    flash[:error] += "\nThis storage is marked as 'offline' until this test pass."
    @provider.update_column(:online, false)

    respond_to do |format|
      format.html do
        redirect_to :action => :show
      end
      format.xml  do
        render :xml  => "fail. #{ex.message}"
      end
      format.json do
        render :json => "fail. #{ex.message}"
      end
    end

  ensure
    File.unlink "#{tmpfile}.out" rescue true
    File.unlink "#{tmpfile}.err" rescue true

  end

  private

  def data_provider_params #:nodoc:
    if current_user.has_role?(:admin_user)
      params.require_as_params(:data_provider).permit(
        :name, :user_id, :group_id, :remote_user, :remote_host, :alternate_host,
        :remote_port, :remote_dir, :online, :read_only, :description, :type,
        :not_syncable, :time_zone,

        :cloud_storage_client_identifier, :cloud_storage_client_token,
        :cloud_storage_client_bucket_name, :cloud_storage_client_path_start,
        :cloud_storage_endpoint, :cloud_storage_region,

        :datalad_repository_url, :datalad_relative_path,
        :license_agreements,
        :containerized_path
      )
    else
      # Normal users are not allowed to change
      # some parameters that would allow them to access things
      # they don't control.
      # remote host data are only editable on user created private storage
      params.require_as_params(:data_provider).permit(
        :name, :description, :group_id, :time_zone,
        :alternate_host,
        *([
            :remote_user, :remote_host, :remote_port, :remote_dir
        ] if @data_provider&.is_a? UserkeyFlatDirSshDataProvider
        ), # allow change dir/host only for user own private storage
        :online, :read_only, :not_syncable,
        :datalad_repository_url, :datalad_relative_path,
        :license_agreements,
        :containerized_path
      )
    end
  end

  def get_type_list #:nodoc:
    data_provider_list = [ "FlatDirSshDataProvider" ]
    if check_role(:site_manager) || check_role(:admin_user)
      data_provider_list = DataProvider.descendants.map(&:name)
    end
    grouped_options = data_provider_list.to_a.hashed_partitions { |name| name.constantize.pretty_category_name }
    grouped_options.delete(nil) # data providers that can not be on this list return a category name of nil, so we remove them
    grouped_options.keys.sort.map { |type| [ type, grouped_options[type].sort ] }
  end

  # A name to store the scope for the browsing page;
  # a distinct scope is used for each distinct DP
  def browse_scope_name(provider) #:nodoc:
    "data_providers#browse##{provider.id}"
  end

  # Quick/small methods to avoid duplication in register/unregister/delete

  # Fetch the user the browse the DP as, based on the provided +as_user_id+
  # or the 'data_providers#browse##{id}' scope.
  def browse_as(provider, as_user_id) #:nodoc:
    scope     = scope_from_session(browse_scope_name(provider))
    users     = current_user.available_users
    as_user   = users.where(:id => as_user_id).first
    as_user ||= users.where(:id => scope.custom['as_user_id']).first
    as_user ||= current_user
    as_user
  end

  # Returns a browse_path value for the current action
  # (this is used in the actions for browsing, registering,
  # (unregistering and deleting). The +path+ argument is
  # usually fetched from the action's params; if it is set
  # to anything non-nil (including the empty string) then
  # that value is used. Otherwise we fetch the latest value
  # recorded in the session's scope. The method always
  # transforms "" and "." into nil, returning that nil.
  def current_browse_path(provider, path)
    return nil if ! provider.has_browse_path_capabilities?
    path = "." if path == "" # we distinguish between nil (unset) and "" (meaning top dir)

    # Find the browse_path in priority order:
    # 1) from the method's argument, 2) from the scope,
    scope    = scope_from_session(browse_scope_name(provider))
    mypath   = path.presence.try(:strip).try(:presence)
    mypath ||= scope.custom['browse_path'].presence
    mypath.try(:strip)
    return nil if mypath.blank? || mypath == '.'

    # Clean and validate each path component
    clean = Userfile.is_legal_browse_path?(mypath)
    cb_error "Browse path is invalid" if ! clean
    clean
  end

  # Fetch the userfiles corresponding to the given +basenames+ for
  # +user+ on +provider+. If the data provider's storage puts
  # files of multiple users together, then the fetched list will
  # also include files from other users! This is to detect and prevent
  # registration of files with same (colliding) names by different users
  # on such providers.
  #
  # Returns a hash with a basename for key, and a userfile as value.
  def userfiles_from_basenames(provider, user, basenames, browse_path) #:nodoc:
    userfiles = provider.userfiles.where(:name => basenames, :browse_path => browse_path)
    userfiles = userfiles.where(:user_id => user.id) if ! provider.content_storage_shared_between_users?
    userfiles = userfiles.index_by(&:name)

    Array(basenames).map { |name| [name, userfiles[name]] }.to_h
  end

  # Send generic success/failure notice messages for +operation+,
  # given the list of failures (+failed+) and successes (+succeeded+).
  #
  # Note that +operation+ is solely used to formulate the message, and 'ing'
  # is tackled at the end. This method is also purely meant to be used for
  # register/unregister/delete and assumes to be working with lists
  # of Userfiles or file names.
  def generic_notice_messages(operation, succeeded, failed, additional_ok_text = "") #:nodoc:
    return unless succeeded.present? || failed.present?

    if succeeded.present?
      # *_message_sender only works on record-like objects
      ok_message = "Finished #{operation}ing file(s)\n" + additional_ok_text
      if succeeded.first.class.respond_to?(:pretty_type)
        notice_message_sender(ok_message, succeeded)
      else
        Message.send_message(current_user,
          :message_type  => :notice,
          :header        => ok_message,
          :variable_text => "For #{view_pluralize(succeeded.count, 'file')}"
        )
      end
    end

    if failed.present?
      if failed.first.last.first.class.respond_to?(:pretty_type)
        error_message_sender("Error when #{operation}ing file(s)", failed)
      else
        report = failed.map do |message, values|
          ["For #{view_pluralize(values.size, 'file')}, #{message}:", values.sort.map { |v| "[#{v}]" }]
        end

        Message.send_message(current_user,
          :message_type  => :error,
          :header        => "Error when #{operation}ing file(s)",
          :variable_text => report.flatten.join("\n")
        )
      end
    end
  end

  # Generate a complete API response from a register-like action
  # following the old format. Mainly used to avoid duplication
  # in register/unregister/delete.
  def generate_register_response #:nodoc:
    {
      :notice                          => flash[:notice],
      :error                           => flash[:error],
      :newly_registered_userfiles      => [],
      :previously_registered_userfiles => [],
      :userfiles_in_transit            => [],
      :num_unregistered                => 0,
      :num_erased                      => 0,
    }
  end

  # Utility method to raise an exception
  # when testing for a DP's configuration.
  def test_error(message) #:nodoc:
    raise UserKeyTestConnectionError.new(message)
  end

end
