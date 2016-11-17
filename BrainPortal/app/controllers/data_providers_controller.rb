
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

# RESTful controller for the DataProvider resource.


class DataProvidersController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  api_available :except => [:cleanup]

  before_filter :login_required
  before_filter :manager_role_required, :only => [:new, :create]
  before_filter :admin_role_required,   :only => [:report, :repair]

  API_HIDDEN_ATTRIBUTES = [ :cloud_storage_client_identifier, :cloud_storage_client_token ]

  def index #:nodoc:
    @scope = scope_from_session('data_providers')
    scope_default_order(@scope, 'name')

    @base_scope = DataProvider
      .find_all_accessible_by_user(current_user)
      .includes(:user, :group)
    @data_providers = @scope.apply(@base_scope)

    respond_to do |format|
      format.html
      format.xml  do
        @data_providers.each { |dp| dp.hide_attributes(API_HIDDEN_ATTRIBUTES) }
        render :xml  => @data_providers
      end
      format.json do
        @data_providers.each { |dp| dp.hide_attributes(API_HIDDEN_ATTRIBUTES) }
        render :json => @data_providers.to_json(
                          :methods => [
                            :type, :is_browsable?, :is_fast_syncing?,
                            :allow_file_owner_change?, :content_storage_shared_between_users?,
                          ] )
      end
      format.js
    end
  end

  # GET /data_providers/1
  # GET /data_providers/1.xml
  def show  #:nodoc:
    data_provider_id = params[:id]
    @provider        = DataProvider.find(data_provider_id)

    cb_notice "Provider not accessible by current user." unless @provider.can_be_accessed_by?(current_user)


    respond_to do |format|
      format.html # show.html.erb
      format.xml  {
          @provider.hide_attributes(API_HIDDEN_ATTRIBUTES)
          render :xml  => @provider
      }
      format.json {
          @provider.hide_attributes(API_HIDDEN_ATTRIBUTES)
          render :json => @provider
      }
    end
  end

  def new #:nodoc:
    provider_group_id = ( current_project && current_project.id ) || current_user.own_group.id
    @provider = DataProvider.new( :user_id   => current_user.id,
                                  :group_id  => provider_group_id,
                                  :online    => true,
                                  :read_only => false
                                )

    @typelist = get_type_list
  end

  def create #:nodoc:
    @provider = DataProvider.sti_new(params[:data_provider])
    @provider.user_id  ||= current_user.id # disabled field in form DOES NOT send value!
    @provider.group_id ||= (( current_project && current_project.id ) || current_user.own_group.id)

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

    fields    = params[:data_provider] || {}
    fields.delete(:type)

    if @provider.update_attributes_with_logging(fields, current_user,
         %w(
           remote_user remote_host remote_port remote_dir
           not_syncable cloud_storage_client_identifier cloud_storage_client_token
         )
      )
      meta_flags_for_restrictions = (params[:meta] || {}).keys.grep(/\Adp_no_copy_\d+\z|\Arr_no_sync_\d+\z/)
      add_meta_data_from_form(@provider, [:must_move, :no_uploads, :no_viewers, :browse_gid] + meta_flags_for_restrictions)
      flash[:notice] = "Provider successfully updated."
      respond_to do |format|
        format.html { redirect_to :action => :show }
        format.xml  { render :xml   => @provider }
        format.json { render :json  => @provider }
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
    flash[:error]  = "Provider not destroyed: #{e.message}"

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
      format.html { render :text => red_if( ! is_alive, "<span>Yes</span>".html_safe, "No" ) }
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
      format.html { render :text => info_by_user.inspect }
      format.xml  { render :xml  => info_by_user }
      format.json { render :json => info_by_user }
    end

  rescue
    respond_to do |format|
      format.html { render :text  => '<strong style="color:red">No Information Available</strong>' }
      format.xml  { head :unprocessable_entity }
      format.json { head :unprocessable_entity }
    end

  end

  # Generates list of providers accessible by the current user.
  # Generates list of users available by the current user.
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

  # Generates list of providers accessible by the current user.
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
    @scope = scope_from_session(default_scope_name)
    scope_filter_from_params(@scope, :name_like, {
      :attribute => 'name',
      :operator  => 'match'
    })

    # Browsing as a different user? Make sure the target user is set.
    @as_user = current_user
      .available_users
      .where(:id => (
        params['as_user_id'] ||
        @scope.custom['as_user_id'] ||
        current_user.id
      ))
      .first
    @as_user ||= current_user
    @scope.custom['as_user_id'] = @as_user.id

    begin
      # [ base, size, type, mtime ]
      @fileinfolist = get_recent_provider_list_all(@provider, @as_user, params[:refresh])
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

    # Let's add three more custom attributes:
    # - the userfile if the file is already registered
    # - the state_ok flag that tell whether or not it's OK to register/unregister
    # - a message.
    if @fileinfolist.size > 0
       @fileinfolist[0].class.class_eval("attr_accessor :userfile, :userfile_id, :state_ok, :message")
    end

    # NOTE: next paragraph for initializing registered_files is also in register() action
    registered_files = Userfile.where( :data_provider_id => @provider.id )
    # On data providers where files are stored in a per user subdir, we limit our
    # search of what's registered to only those belonging to @as_user;
    # otherwise we must report when files are registered by other users too.
    registered_files = registered_files.where( :user_id => @as_user.id ) if ! @provider.content_storage_shared_between_users?
    registered_files = registered_files.all.index_by(&:name)

    @fileinfolist.each do |fi|
      fi_name  = fi.name
      fi_type  = fi.symbolic_type

      # Special local attributes
      fi.userfile    = nil
      fi.userfile_id = nil
      fi.message     = ""
      fi.state_ok    = true

      # Add additional info if file is already registered
      registered = registered_files[fi_name]
      if registered
        fi.userfile    = registered # the userfile object itself
        fi.userfile_id = registered.id
        unless ((fi_type == :symlink)                                    ||
                (fi_type == :regular    && registered.is_a?(SingleFile)) ||
                (fi_type == :directory  && registered.is_a?(FileCollection)))
          fi.message  = "Conflicting types!"
          fi.state_ok = false
        end
        next
      end

      # Otherwise, if not registered, check filename's validity
      if ! Userfile.is_legal_filename?(fi_name)
        fi.message = "Illegal characters in filename."
        fi.state_ok = false
      end

    end

    # Now that @fileinfolist is complete, apply @scope's elements and paginate
    # before display.
    @fileinfolist = @scope.apply(@fileinfolist)

    @scope.pagination ||= Scope::Pagination.from_hash({ :per_page => 25 })
    @files = @scope.pagination.apply(@fileinfolist) unless
      [:xml, :json].include?(request.format.to_sym)

    scope_to_session(@scope)

    respond_to do |format|
      format.html
      format.xml do
        @fileinfolist.each { |fil| fil.instance_eval {remove_instance_variable :@userfile} }
        render :xml  => @fileinfolist
      end
      format.json do
        @fileinfolist.each { |fil| fil.instance_eval {remove_instance_variable :@userfile} }
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
    @provider = DataProvider.find_accessible_by_user(params[:id], current_user)
    @as_user  = browse_as(params['as_user_id'])
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
    group_id = current_project.try(:id) || current_user.own_group.id

    # Unless one was specified explicitly via :other_group_id
    group_id = params[:other_group_id].to_i unless
      params[:other_group_id].blank?

    # Fallback to the user's own project if the one selected above is invalid
    # (the everyone project, under which no file is ever registered, or a
    # project the user doesn't have access to).
    group_id = current_user.own_group.id if (
      group_id == Group.everyone.id ||
      ! current_user.available_groups.raw_first_column('groups.id').include?(group_id)
    )

    # Remind the user if browsing as another user
    flash[:notice] += "Important note! Since you were browsing as user '#{@as_user.login}', the files will be registered as belonging to that user instead of you!\n" if
      @as_user != current_user

    # Register the given userfiles in background.
    userfiles = userfiles_from_basenames(@provider, @as_user, params[:basenames])
    userfiles_count = userfiles.count # Avoids a cute race condition

    registered, already_registered = [], []
    succeeded, failed = [], {}

    CBRAIN.spawn_with_active_records_if(
      [:html, :js].include?(request.format.to_sym),
      current_user,
      "Register files (data_provider: #{@provider.id})"
    ) do
      userfiles.keys.shuffle.each do |basename|
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
            :data_provider_id => @provider.id
          )

          # And save it
          if userfile.save
            userfile.addlog_context(self, "Registered on DataProvider '#{@provider.name}' as '#{userfile.name}' by #{current_user.login}.")
            registered << (userfiles[basename] = userfile)
            succeeded << basename
          else
            (failed["Unspecified error"] ||= []) << basename
          end

        rescue => e
          (failed[e.message] ||= []) << basename
        end
      end

      # If files actually got registered, clear the browsing cache
      clear_browse_provider_local_cache_file(@as_user, @provider) if
        succeeded.present? && [:html, :js].include?(request.format.to_sym)

      # No need to move or copy? Just set the file sizes and exit.
      unless post_action
        registered.each { |userfile| userfile.set_size! rescue true }
        generic_notice_messages('register', succeeded, failed)
        next
      end

      # Notify user of registration successes and failures.
      mangled_action = (post_action == :move ? 'mov' : 'copi')
      generic_notice_messages('register', succeeded, failed,
        "Files will now be #{mangled_action}ed in background.")

      # Prepare to copy/move the files to the new DP
      succeeded, failed = [], {}

      # Will some of the file names collide?
      collisions = Userfile
        .where(
          :name             => registered.map(&:name),
          :user_id          => @as_user.id,
          :data_provider_id => target_dp.id
        )
        .raw_first_column('userfiles.name')
        .to_set

      userfiles = registered.reject { |r| collisions.include?(r.name) }
      if collisions.present?
        failed["Filename collision"] ||= []
        failed["Filename collision"]  += collisions
      end

      # Copy/move each file
      userfiles.shuffle.each_with_index do |userfile, ix|
        $0 = "#{post_action.to_s.humanize} registered files ID=#{userfile.id} #{ix + 1}/#{userfiles.size}\0\0\0\0"

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

      generic_notice_messages(mangled_action, succeeded, failed)
    end

    # Generate a complete response matching the old API
    flash[:notice] += "Registering #{userfiles_count} userfile(s) in background.\n"
    api_response = generate_register_response.merge({
      :newly_registered_userfiles      => registered,
      :previously_registered_userfiles => already_registered
    })

    respond_to do |format|
      format.html { redirect_to :action => :browse }
      format.json { render :json => api_response }
      format.json { render :xml  => api_response }
    end
  end

  # Unregister (and optionally delete) a list of files (+basenames+) from a given
  # CBRAIN data provider (parameter +id+). This action accepts 2 optional parameters;
  # +as_user_id+ to unregister as a given user rather than as the current user, and
  # +delete+, if files are to be deleted once unregistered.
  # Note that unregistration will happen in background for HTML & JS requests.
  def unregister
    # Extract key parameters & make sure the provider is browsable
    @provider = DataProvider.find_accessible_by_user(params[:id], current_user)
    @as_user  = browse_as(params['as_user_id'])
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
    userfiles = userfiles_from_basenames(@provider, @as_user, params[:basenames])
    succeeded, failed = [], {}
    erasing = params.has_key?(:delete)

    CBRAIN.spawn_with_active_records_if(
      [:html, :js].include?(request.format.to_sym),
      current_user,
      "Unregister files (data_provider: #{@provider.id})"
    ) do
      userfiles.reject { |b,u| u.blank? }.to_a.shuffle.each do |basename, userfile|
        begin
          # Make sure the current user can unregister the file
          unless userfile.has_owner_access?(current_user)
            (failed["Insufficient permissions"] ||= []) << basename
            next
          end

          # Userfile.delete will not delete the contents, but destroy will
          result = (erasing ? userfile.destroy : Userfile.delete(userfile.id))
          userfile.destroy_log rescue true

          (result ? succeeded : (failed["Unspecified error"] ||= [])) << basename
        rescue => e
          (failed[e.message] ||= []) << basename
        end
      end

      # If files actually got erased, clear the browsing cache
      clear_browse_provider_local_cache_file(@as_user, @provider) if
        erasing && succeeded.present? && [:html, :js].include?(request.format.to_sym)

      generic_notice_messages('unregister', succeeded, failed)
    end

    # Generate a complete response matching the old API
    flash[:notice] += "Unregistering #{userfiles.size} userfile(s) in background.\n"

    api_response = generate_register_response
    api_response[erasing ? :num_erased : :num_unregistered] = succeeded.size

    respond_to do |format|
      format.html { redirect_to :action => :browse }
      format.json { render :json => api_response }
      format.json { render :xml  => api_response }
    end
  end

  # Delete a list of files (+basenames+) from a given CBRAIN data provider
  # (parameter +id+). This action differs from +unregister+ (with +delete+
  # option) by not requiring the files to be registered in CBRAIN. As with
  # +register+ and +unregister+, a +as_user_id+ parameter is supported and
  # the deletion occurs in background.
  def delete
    # Extract key parameters & make sure the provider is browsable
    @provider = DataProvider.find_accessible_by_user(params[:id], current_user)
    @as_user  = browse_as(params['as_user_id'])
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
    userfiles = userfiles_from_basenames(@provider, @as_user, params[:basenames])
    succeeded, failed = [], {}

    CBRAIN.spawn_with_active_records_if(
      [:html, :js].include?(request.format.to_sym),
      current_user,
      "Delete files (data_provider: #{@provider.id})"
    ) do
      userfiles.to_a.shuffle.each do |basename, userfile|
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
              :group_id      => current_user.own_group.id
            ).freeze

            result = @provider.provider_erase(temporary)
          end

          (result ? succeeded : (failed["Unspecified error"] ||= [])) << basename
        rescue => e
          (failed[e.message] ||= []) << basename
        end
      end

      # If files actually got erased, clear the browsing cache
      clear_browse_provider_local_cache_file(@as_user, @provider) if
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
      format.json { render :json => api_response }
      format.json { render :xml  => api_response }
    end
  end

  # Report inconsistencies in the data provider.
  def report
    @scope    = scope_from_session(default_scope_name)
    @provider = DataProvider.find(params[:id])
    @issues   = @provider.provider_report(params[:reload])

    scope_default_order(@scope, :severity)
    @scope.pagination ||= Scope::Pagination.from_hash({ :per_page => 25 })
    @view_scope = @scope.apply(@issues, paginate: true)

    respond_to do |format|
      format.html
      format.js
      format.xml  { render :xml  => { :issues => @issues } }
      format.json { render :json => { :issues => @issues } }
    end
  end

  # Repair one or more inconsistencies in the data provider.
  def repair
    @provider = DataProvider.find(params[:id])
    @issues   = @provider.provider_report.select { |i| params[:issue_ids].include? i[:id].to_s }

    # Try to repair the inconsistencies (or issues)
    failed_list  = []
    success_list = []
    @issues.each do |issue|
      begin
        @provider.provider_repair(issue)
        success_list << issue
      rescue => ex
        failed_list  << [issue, ex]
      end
    end

    # Display a message reporting how many issues were repaired
    unless @issues.empty?
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
          :variable_text => failed_list.map { |issue,ex| "|#{issue[:message]}|: #{ex.message}\n" }.join
        )
      end
    end

    api_response = {
      :repaired => success_list,
      :failed   => failed_list.map { |issue,ex| { :issue => issue, :exception => ex.message } }
    }

    respond_to do |format|
      format.html { redirect_to :action => :report }
      format.xml  { render      :xml    => api_response }
      format.json { render      :json   => api_response }
    end
  end

  private

  def get_type_list #:nodoc:
    data_provider_list = [ "FlatDirSshDataProvider" ]
    if check_role(:site_manager) || check_role(:admin_user)
      data_provider_list = DataProvider.descendants.map(&:name)
    end
    grouped_options = data_provider_list.hashed_partitions { |name| name.constantize.pretty_category_name }
    grouped_options.delete(nil) # data providers that can not be on this list return a category name of nil, so we remove them
    grouped_options.keys.sort.map { |type| [ type, grouped_options[type].sort ] }
  end

  # Quick/small methods to avoid duplication in register/unregister/delete

  # Fetch the user the browse the DP as, based on the provided +as_user_id+
  # and the 'data_providers#browse' scope.
  def browse_as(as_user_id) #:nodoc:
    scope      = scope_from_session('data_providers#browse')
    @as_user   = current_user
      .available_users
      .where(:id => scope.custom['as_user_id'] ||= (
        params['as_user_id'] || current_user.id
      ))
      .first
    @as_user ||= current_user
  end

  # Fetch the userfiles corresponding to the given +basenames+ for
  # +user+ on +provider+. If the data provider's storage puts
  # files of multiple users together, then the fetched list will
  # also include files from other users! This is to detect and prevent
  # registration of files with clashing names by different users.
  #
  # Returns a hash with a basename for key, and a userfile as value.
  def userfiles_from_basenames(provider, user, basenames) #:nodoc:
    userfiles = provider.userfiles.where(:name => basenames)
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

  # Note: the following methods should all be part of one of the subclasses of DataProvider, probably.

  def browse_provider_local_cache_file(user, provider) #:nodoc:
    cache_file = "/tmp/dp_cache_list_all_#{user.id}.#{provider.id}"
    cache_file
  end

  def get_recent_provider_list_all(provider, as_user = current_user, refresh = false) #:nodoc:

    refresh = false if refresh.blank? || refresh.to_s == 'false'

    # Check to see if we can simply reload the cached copy
    cache_file = browse_provider_local_cache_file(as_user, provider)
    if ! refresh && File.exist?(cache_file) && File.mtime(cache_file) > 60.seconds.ago
       filelisttext = File.read(cache_file)
       fileinfolist = YAML.load(filelisttext)
       return fileinfolist
    end

    # Get info from provider
    fileinfolist = provider.provider_list_all(as_user)

    # Write a new cached copy
    save_browse_provider_local_cache_file(as_user, provider, fileinfolist)

    # Return it
    fileinfolist
  end

  def save_browse_provider_local_cache_file(user, provider, fileinfolist) #:nodoc:
    cache_file = browse_provider_local_cache_file(user, provider)
    tmpcachefile = cache_file + ".#{Process.pid}.tmp";
    File.open(tmpcachefile,"w") do |fh|
       fh.write(YAML.dump(fileinfolist))
    end
    File.rename(tmpcachefile,cache_file) rescue true  # crush it
  end

  def clear_browse_provider_local_cache_file(user, provider) #:nodoc:
    cache_file = browse_provider_local_cache_file(user, provider)
    File.unlink(cache_file) rescue true
  end

end
