
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

require 'fileutils'

# RESTful controller for the Userfile resource.
class UserfilesController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  api_available

  before_action :login_required

  skip_before_action :verify_authenticity_token, :only => [ :download ] # we check it ourselves in download()

  around_action :permission_check, :only => [
      :download, :update_multiple, :delete_files,
      :create_collection, :change_provider, :quality_control,
      :export_file_list
  ]

  MAX_DOWNLOAD_MEGABYTES = 400

  # GET /userfiles
  # GET /userfiles.xml
  # GET /userfiles.json
  def index #:nodoc:
    @scope = scope_from_session

    # Manually handle the 'name_like' input, as it cant be pre-computed
    # server-side (and going the JS route would be overkill).
    params[:name_like].strip! if params[:name_like]
    scope_filter_from_params(@scope, :name_like, {
      :attribute => 'name',
      :operator  => 'match'
    })

    # Apply basic and @scope-based scoping/filtering
    scope_default_order(@scope, 'name')
    @base_scope   = base_scope #.includes([:user, :data_provider, :sync_status, :tags, :group])
    @custom_scope = custom_scope(@base_scope)

    if @scope.custom[:view_hidden]
      @view_scope   = @scope.apply(@custom_scope)
    else
      @hidden_total = @scope.apply(@custom_scope.where(:hidden => true)).count
      @view_scope   = @scope.apply(@custom_scope.where(:hidden => false))
    end

    # Generate tag filters
    tag_counts   = @view_scope.joins(:tags).group('tags.name').count
    @tag_filters = @base_scope
      .joins(:tags)
      .group('tags.name')
      .raw_rows(['tags.name', 'tags.id', 'COUNT(tags.name)'])
      .map do |name, id, count|
        {
          :value     => id,
          :label     => name,
          :indicator => tag_counts[name].to_i,
          :empty     => tag_counts[name].blank?
        }
      end

    # Generate display totals
    @userfiles_total      = @view_scope.count('distinct userfiles.id')
    @archived_total       = @view_scope.where(:archived  => true).count
    @immutable_total      = @view_scope.where(:immutable => true).count
    @userfiles_total_size = @view_scope.sum(:size)

    # Prepare the Pagination object
    @scope.pagination ||= Scope::Pagination.from_hash({ :per_page => 25 })
    @current_offset = (@scope.pagination.page - 1) * @scope.pagination.per_page

    # Special case; only userfile IDs are required (API request)
    if params[:ids_only] && api_request?
      @userfiles = @view_scope.raw_first_column('userfiles.id')

    # Tree sort
    elsif @scope.custom[:tree_sort]
      # Sort using just IDs and parent IDs then paginate, giving the final
      # userfiles list in tuple (see +tree_sort_by_pairs+) form.
      tuples = tree_sort_by_pairs(@view_scope.raw_rows(['userfiles.id', 'userfiles.parent_id']))
      tuples = @scope.pagination.apply(tuples) unless api_request?

      # Keep just ID and depth/level; there is no need for the parent ID,
      # children list, original index, etc.
      tuples.map! { |t| [t[0].to_i, t[4]] }

      # Map the corresponding Userfile objects in @view_scope by ID.
      mapping = @view_scope
        .where(:id => tuples.map { |t| t.first })
        .index_by { |u| u.id }

      # Convert the tuple list to Userfile objects using the mapping, conserving
      # the tuple list's ordering and pagination information.
      @userfiles = tuples.map! do |id, level|
        userfile = mapping[id]
        next unless userfile

        userfile.level = level
        userfile
      end

      # Remove invalid entries (occur when the list changes between the sort
      # and conversion).
      @userfiles.compact!

    # General case
    else
      @userfiles = @view_scope
      @userfiles = @scope.pagination.apply(@userfiles)
    end

    # Save the modified scope object
    scope_to_session(@scope)

    # This is for the tool selection dialog box....
    # we need the tools the user has access to and tags associated with the tools
    @my_tools    = current_user.available_tools.where("tools.category <> 'background'").all.to_a
    top_tool_ids = current_user.meta[:top_tool_ids] || {}

    if top_tool_ids.present?
      # Define top 5 tools for current users
      top_5_tool_ids  = (top_tool_ids.sort_by { |k,v| -v } [0..4]).map { |pair| pair[0] }
      top_5_tools     = @my_tools.select { |t| top_5_tool_ids.include?(t.id) }

      # Put the top 5 at beginning of the list
      @my_tools = @my_tools   - top_5_tools
      @my_tools = top_5_tools + @my_tools
    end

    # Handles the case when we just switched active project in group_controller/switch
    if cbrain_session[:switched_active_group]
      cbrain_session.delete(:switched_active_group)
      @force_clear_persistent = 1 # HTML page will have extra javascript code to clear the list
    end

    respond_to do |format|
      format.html
      format.js
      format.xml  { render :xml  => (params[:ids_only].present? && api_request?) ? @userfiles.to_a : @userfiles.for_api }
      format.json { render :json => (params[:ids_only].present? && api_request?) ? @userfiles.to_a : @userfiles.for_api }
      format.csv
    end
  end

  def new_parent_child #:nodoc:

    file_ids     = params[:file_ids]
    @userfiles   = Userfile.find_all_accessible_by_user(current_user, :access_requested => :write).where(:id => file_ids).all.to_a
    @have_parent = @userfiles.any? { |u| u.parent_id  }
    if ! ( @userfiles.size >= 2  || @have_parent )
      render :html  => "<span class=\"warning\">You must select either:<br> 1) several files without parents or<br> 2) one file with a parent.</span>".html_safe
      return
    end

    render :action  => :new_parent_child, :layout  => false
  end

  def create_parent_child #:nodoc:
    parent_id = params[:parent_id]
    child_ids = params[:child_ids]

    if child_ids.blank?
      flash[:error] = "Must have at least one file selected for this operation."
    else
      child_ids.delete(parent_id)
      @children = Userfile.find_accessible_by_user(params[:child_ids], current_user)
      @parent   = parent_id.present? && Userfile.find_accessible_by_user(params[:parent_id], current_user)
      @parent ? @children.each { |c| c.move_to_child_of(@parent) }
              : @children.each { |c| c.remove_parent() }
    end

    redirect_to :action => :index
  end

  # Use the rest of the route as a path into a file collection.
  # [:file_path] a path relative to the file collection's route directory.
  #
  # GET /userfiles/1/file_collection_content/path/to/file/in/file_collection
  def file_collection_content
    @userfile = Userfile.find_accessible_by_user(params[:id], current_user, :access_requested => :read)
    if @userfile.nil?
      raise ActiveRecord::RecordNotFound("Could not retrieve a userfile with ID: #{params[:id]}")
    end
    path = @userfile.cache_full_path.to_s + '/' + params[:file_path]
    if params[:format]
      path += '.' + params[:format]
    end
    if not File.file?(path)
      head :not_found
      return
    end
    final_path = Pathname.new(path).realpath rescue nil
    if not final_path.to_s.start_with? @userfile.cache_full_path.to_s
      head :unauthorized
      return
    end
    if params[:format] == 'html'
      render file: path, layout: false
    else
      send_file path
    end
  end

  # Transfer contents of a file.
  # If no relevant parameters are given, the controller
  # will simply attempt to send the entire file.
  # Otherwise, it will modify it's response according
  # to the following parameters:
  # [:content_loader] a content loader defined for the
  #                   userfile.
  # [:arguments]      arguments to pass to the content
  #                   loader method.
  #
  # GET /userfiles/1/content?option1=....optionN=...
  def content
    @userfile = Userfile.find_accessible_by_user(params[:id], current_user, :access_requested => :read)

    content_loader = @userfile.find_content_loader(params[:content_loader])
    argument_list  = params[:arguments] || []
    argument_list  = [argument_list] unless argument_list.is_a?(Array)

    if !content_loader
      @userfile.sync_to_cache
      send_file @userfile.cache_full_path, :stream => true, :filename => @userfile.name, :disposition => (params[:disposition] || "attachment")
      return
    end

    response_content = @userfile.send(content_loader.method, *argument_list)

    if content_loader.type == :send_file
      send_file response_content
    elsif content_loader.type == :gzip
      response.headers["Content-Encoding"] = "gzip"
      render :plain => response_content
    elsif content_loader.type == :text
      render :plain => response_content
    else
      render content_loader.type => response_content
    end
  rescue
    respond_to do |format|
       format.html { render :file    => "public/404.html", :status => 404 }
       format.xml  { head   :not_found }
       format.json { head   :not_found }
    end
  end

  # Renders a partial within the 'show' page by invoking
  # some custom viewer code registered by a Userfile subclass.
  # The main parameter is :viewer ; an optional :viewer_userfile_class
  # can be provided to override which class to search for the viewer code
  # (by default, the class of +userfile+)
  def display
    @userfile = Userfile.find_accessible_by_user(params[:id], current_user, :access_requested => :read)

    viewer_name           = params[:viewer]
    viewer_userfile_class = params[:viewer_userfile_class].presence.try(:constantize) || @userfile.class

    # Try to find out viewer among those registered in the classes
    @viewer      = viewer_userfile_class.find_viewer(viewer_name)
    @viewer    ||= (viewer_name.camelcase.constantize rescue nil).try(:find_viewer, viewer_name) rescue nil

    # If no viewer object is found but the argument "viewer_name" correspond to a partial
    # on disk, then let's create a transient viewer object representing that file.
    # Not an officially registered viewer, but it will work for the current rendering.
    if @viewer.blank? && viewer_name =~ /\A\w+\z/
      partial_filename_base = (viewer_userfile_class.view_path + "_#{viewer_name}.#{request.format.to_sym}").to_s
      if File.exists?(partial_filename_base) || File.exists?(partial_filename_base + ".erb")
        @viewer = Userfile::Viewer.new(viewer_userfile_class, :partial => viewer_name)
      end
    end

    # Some viewers return error(s) for some specific userfiles
    if (params[:content_viewer] != 'off')
      @viewer.apply_conditions(@userfile) if @viewer
    end

    begin
      if @viewer
        if @viewer.errors.present?
          render :partial => "viewer_errors"
        elsif params[:apply_div] == "false"
          render :file   => @viewer.partial_path.to_s, :layout => params[:apply_layout].present?
        else
          render :action => :display,                  :layout => params[:apply_layout].present?
        end
      else
        render :html => "<div class=\"warning\">Could not find viewer #{viewer_name}.</div>".html_safe, :status  => "404"
      end
    rescue ActionView::Template::Error => e
      exception = e.original_exception

      raise exception unless Rails.env == 'production'
      ExceptionLog.log_exception(exception, current_user, request)
      Message.send_message(current_user,
        :message_type => 'error',
        :header => "Could not view #{@userfile.name}",
        :description => "An internal error occurred when trying to display the contents of #{@userfile.name}."
      )

      render :html => "<div class=\"warning\">Error generating view code for viewer #{params[:viewer]}.</div>".html_safe, :status => "500"
    end
  end

  def show #:nodoc:
    @userfile = Userfile.find_accessible_by_user(params[:id], current_user, :access_requested => :read)

    # This allows the user to manually trigger the syncing to the Portal's cache
    @sync_status        = 'ProvNewer' # same terminology as in SyncStatus
    state               = @userfile.local_sync_status
    @sync_status        = state.status if state
    @viewer             = @userfile.find_viewer_with_applied_conditions(params[:viewer]) if params[:viewer].present?

    @viewers            = @userfile.viewers_with_applied_conditions || []
    @viewer           ||= @viewers.detect { |v| v.errors.empty?} || @viewers.first

    @log                = @userfile.getlog        rescue nil

    # Prepare next/previous userfiles for html
    if ! api_request?
      @sort_index  = [ 0, params[:sort_index].to_i, 999_999_999 ].sort[1]

      # Rebuild the sorted Userfile scope
      @scope       = scope_from_session('userfiles#index')
      sorted_scope = filtered_scope

      # Fetch the neighbors of the shown userfile in the ordered scope's order
      neighbors = sorted_scope.where("userfiles.id != ?", @userfile.id).offset([0, @sort_index - 1].max).limit(2).all.to_a
      neighbors.unshift nil if @sort_index == 0

      @previous_userfile, @next_userfile = neighbors
    end

    respond_to do |format|
      format.html
      format.xml  { render :xml  => @userfile.for_api }
      format.json { render :json => @userfile.for_api }
    end
  end

  # Triggers the mass synchronization of several userfiles
  # or mass 'desynchronization' (ProvNewer) of several userfiles.
  def sync_multiple #:nodoc:

    operation = params[:operation] || "sync_local"  # that, or "all_newer"

    @userfiles = Userfile.find_accessible_by_user(params[:file_ids], current_user, :access_requested => :read)

    # Mark files as newer on provider side
    if operation == "all_newer" # simpler case
      updated = 0
      SyncStatus.where(:userfile_id => @userfiles.map(&:id), :status => [ "InSync" ]).all.each do |ss|
        updated += 1 if ss.status_transition(ss.status,"ProvNewer")
      end
      flash[:notice] = "Marked #{updated} files as newer on their Data Provider."
      redirect_to :action  => :index
      return
    end

    # Sync files to the portal's cache
    CBRAIN.spawn_with_active_records(current_user, "Synchronization of #{@userfiles.size} files.") do
      @userfiles.shuffle.each do |userfile|
        state = userfile.local_sync_status
        sync_status = 'ProvNewer'
        sync_status = state.status if state

        if sync_status !~ /^To|InSync|Corrupted/
          if (userfile.sync_to_cache rescue nil)
            userfile.set_size
          end
        end
      end
    end # spawn

    flash[:notice] = "Synchronization started in background. Files that cannot be synchronized will be skipped."

    respond_to do |format|
      format.html do
        if @userfiles.size == 1 && params[:back_to_show_page]
          redirect_to :controller => :userfiles, :action  => :show, :id => @userfiles[0].id
        else
          redirect_to :action  => :index
        end
      end
      format.xml  { head :ok }
      format.json { head :ok }
    end
  end

  # POST /userfiles
  # POST /userfiles.xml
  # POST /userfiles.json

  #The create action is used to save uploaded files to a DataProvider.
  #
  #Generally, the file is simply saved to the DataProvider as is.
  #There are, however, special options for archive files (.tar, .tar.gz, or .zip).
  #Given the value of the +archive+ parameter, the user may perform one
  #of the following on the uploaded archive.
  #[*save*] Save the archive to the DataProvider as is.
  #[*collection*] Extract the files from the archive into a FileCollection.
  #[*extract*] Extract the files in the archive and individually register
  #            them as Userfile entries. This option is limited in that
  #            a maximum of 50 files may be extracted in this way, and
  #            no files nested within directories will be extracted
  #            (the +collection+ option has no such limitations).
  def create #:nodoc:

    flash[:error]     ||= ""
    flash[:notice]    ||= ""

    # Mode of upload; this is determined by the values of the
    # params :_do_extract, and :_up_ex_mode
    mode = :save           # standard upload of one file
    mode = :collection if  params[:_do_extract] == "on" && params[:_up_ex_mode] == "collection" # create a single collection
    mode = :extract    if  params[:_do_extract] == "on" && params[:_up_ex_mode] == "multiple"   # create many many files

    redirect_path = params[:redirect_to] || {:action  => :index}

    # Get the upload stream object
    upload_stream = params[:upload_file]   # an object encoding the file data stream
    if upload_stream.blank?
      respond_to do |format|
        format.html  { redirect_to redirect_path }
        format.json  { head :unprocessable_entity }
      end
      return
    end

    # Save raw content of the file; we don't know yet
    # whether it's an archive or not, or if we'll extract it etc.
    basename    = File.basename(upload_stream.original_filename)

    # Identify the file type
    file_type   = params[:file_type].presence.try(:constantize) rescue nil
    file_type ||= Userfile.suggested_file_type(basename) || SingleFile
    file_type   = SingleFile unless file_type < Userfile

    # Temp file where the data is saved by rack
    rack_tempfile_path = upload_stream.tempfile.path
    rack_tempfile_size = upload_stream.tempfile.size

    # Get the data provider for the destination files.
    data_provider_id   = params[:data_provider_id]

    # Where we'll keep a copy in the spawn() below
    tmpcontentfile     = "/tmp/#{Process.pid}-#{rand(10000).to_s}-#{basename}" # basename's extension is used later on

    # Decide what to do with the raw data
    if mode == :save  # the simplest case first

      userfile  = file_type.new(
                      userfile_params.merge(
                     :name             => basename,
                     :user_id          => current_user.id,
                     :data_provider_id => data_provider_id,
                     :tag_ids          => params[:tags]
                   )
                 )
      userfile.group_id = current_user.own_group.id unless
        current_user.assignable_group_ids.include?(userfile.group_id.to_i)

      if !userfile.save
        flash[:error]  += "File '#{basename}' could not be added.\n"
        userfile.errors.each do |field, error|
          flash[:error] += "#{field.to_s.capitalize} #{error}.\n"
        end
        respond_to do |format|
          format.html { redirect_to redirect_path }
          format.json { render :json => { :notice => flash[:error] }, :status => :unprocessable_entity }
        end
        return
      end

      flash[:notice] += "File '#{basename}' being added in background."

      system("cp #{rack_tempfile_path.to_s.bash_escape} #{tmpcontentfile.to_s.bash_escape}") # fast, hopefully; maybe 'mv' would work?
      CBRAIN.spawn_with_active_records(current_user,"Upload of SingleFile") do
        begin
          userfile.cache_copy_from_local_file(tmpcontentfile)
          userfile.size = rack_tempfile_size
          userfile.save
          userfile.addlog_context(self, "Uploaded by #{current_user.login}")
          Message.send_message(current_user,
                               :message_type   => 'notice',
                               :header         => "File Uploaded",
                               :variable_text  => "#{userfile.pretty_type} [[#{userfile.name}][/userfiles/#{userfile.id}]]"
                               )
        ensure
          File.delete(tmpcontentfile) rescue true
        end
      end # spawn

      respond_to do |format|
        format.html { redirect_to redirect_path }
        format.json { render :json => {:notice => "File Uploaded"}, :status => :created }
        format.xml  { render :xml  => {:notice => "File Uploaded"}, :status => :created }
      end
      return
    end # save

    # At this point the controller implements mode == :collection, or mode == :extract.

    # We will be processing some archive file.
    # First, check for supported extensions
    if basename !~ /(\.tar|\.tgz|\.tar.gz|\.zip)\z/i
      flash[:error] += "Error: file #{basename} does not have one of the supported extensions: .tar, .tar.gz, .tgz or .zip.\n"
      respond_to do |format|
        format.html { redirect_to redirect_path }
        format.json { render :json => flash[:error], :status  => :unprocessable_entity}
        format.xml  { render :xml  => flash[:error], :status  => :unprocessable_entity}
      end
      return
    end

    # Create a collection
    if mode == :collection

      collection_name = basename.split('.')[0]  # "abc"
      if current_user.userfiles.exists?(:name => collection_name, :data_provider_id => data_provider_id)
        flash[:error] = "Collection '#{collection_name}' already exists.\n"
        respond_to do |format|
          format.html { redirect_to redirect_path }
          format.json { render :json => flash[:error], :status  => :unprocessable_entity}
          format.xml  { render :xml  => flash[:error], :status  => :unprocessable_entity}
        end
        return
      end

      collectionType = file_type
      collectionType = FileCollection unless file_type <= FileCollection

      collection = collectionType.new(
        userfile_params.merge(
          :name              => collection_name,
          :user_id           => current_user.id,
          :data_provider_id  => data_provider_id,
          :tag_ids           => params[:tags]
        )
      )

      if collection.save
        system("cp #{rack_tempfile_path.to_s.bash_escape} #{tmpcontentfile.to_s.bash_escape}") # fast, hopefully; maybe 'mv' would work?
        CBRAIN.spawn_with_active_records(current_user, "FileCollection Extraction") do
          begin
            collection.extract_collection_from_archive_file(tmpcontentfile)
            Message.send_message(current_user,
                                  :message_type   => 'notice',
                                  :header         => "Collection Uploaded",
                                  :variable_text  => "#{collection.pretty_type} [[#{collection.name}][/userfiles/#{collection.id}]]"
                                  )
          ensure
            File.delete(tmpcontentfile) rescue true
          end
        end # spawn

        flash[:notice] = "Collection '#{collection_name}' created."
        current_user.addlog_context(self,"Uploaded #{collection.class} '#{collection_name}'")
        respond_to do |format|
          format.html { redirect_to redirect_path }
          format.json { render :json => {:notice => "Collection Uploaded" } }
          format.xml  { render :xml  => {:notice => "Collection Uploaded" } }
        end
      else
        flash[:error] = "Collection '#{collection_name}' could not be created.\n"
        collection.errors.each do |field, error|
          flash[:error] += field.to_s.capitalize + " " + error + ".\n"
        end
        respond_to do |format|
          format.html { redirect_to redirect_path }
          format.json { render :json => flash[:error], :status  => :unprocessable_entity}
          format.xml  { render :xml  => flash[:error], :status  => :unprocessable_entity}
        end
      end # save collection
      return
    end

    # At this point, create a bunch of userfiles from the archive
    cb_error "Unknown upload mode '#{mode}'" if mode != :extract

    # Common attributes to all files
    attributes = userfile_params.merge({
      :user_id           => current_user.id,
      :data_provider_id  => data_provider_id,
      :tag_ids           => params[:tags]
    })

    # Do it in background.
    system("cp #{rack_tempfile_path.to_s.bash_escape} #{tmpcontentfile.to_s.bash_escape}") # fast, hopefully; maybe 'mv' would work?
    CBRAIN.spawn_with_active_records(current_user,"Archive extraction") do
      begin
        extract_from_archive(tmpcontentfile, nil, attributes) # generates its own Messages
      ensure
        File.delete(tmpcontentfile) rescue true
      end
    end # spawn

    flash[:notice] += "Your files are being extracted and added in background."
    respond_to do |format|
      format.html { redirect_to redirect_path }
      format.json { render :json => {:notice => "Archive Uploaded" } }
      format.xml  { render :xml  => {:notice => "Archive Uploaded" } }
    end
  end

  # PUT /userfiles/1
  # PUT /userfiles/1.xml
  # PUT /userfiles/1.json
  def update  #:nodoc:
    @userfile = Userfile.find_accessible_by_user(params[:id], current_user, :access_requested => :write)

    flash[:notice] = ""
    flash[:error]  = ""

    if @userfile.has_owner_access?(current_user)
      new_userfile_attr = userfile_params
      new_user_id       = new_userfile_attr.delete :user_id
      new_group_id      = new_userfile_attr.delete :group_id
      type              = new_userfile_attr.delete :type

      old_name = @userfile.name
      new_name = new_userfile_attr.delete(:name) || old_name

      new_userfile_attr.delete :data_provider_id # cannot be changed here

      @userfile.attributes = new_userfile_attr
      @userfile.type       = type         if type
      @userfile.user_id    = new_user_id  if current_user.available_users.where(:id => new_user_id).exists?
      @userfile.group_id   = new_group_id if current_user.assignable_groups.where(:id => new_group_id).exists?
      @userfile            = @userfile.class_update

      if @userfile.save_with_logging(current_user, %w( group_writable num_files parent_id hidden ) )
        if new_name != old_name
          @userfile.provider_rename(new_name)
          @userfile.addlog("Renamed by #{current_user.login}: #{old_name} -> #{new_name}")
        end
      end
    end

    @userfile.set_tags_for_user(current_user, params[:tag_ids])
    respond_to do |format|
      if @userfile.errors.empty?
        flash[:notice] += "#{@userfile.name} successfully updated."
        format.html { redirect_to(:action  => 'show') }
        format.xml  { head :ok }
        format.json { head :ok }
      else
        @userfile.reload
        format.html { render(:action  => 'show') }
        format.xml  { render :xml  => @userfile.errors, :status => :unprocessable_entity }
        format.json { render :json => @userfile.errors, :status => :unprocessable_entity }
      end
    end
  end

  # Update tags, groups or group-writability flags for several
  # userfiles.
  def update_multiple #:nodoc:
    file_ids = (params[:file_ids] || []).map(&:to_i)
    accepted_params = [
      :user_id,
      :group_id,
      :group_writable,
      :type,
      :hidden,
      :immutable,
    ]
    changes = params.slice(*accepted_params, :tags)
    changes = changes.permit(*accepted_params, :tags => [])

    changes[:user_id]  = changes[:user_id].to_i                      if changes.has_key?(:user_id)
    changes[:group_id] = changes[:group_id].to_i                     if changes.has_key?(:group_id)
    changes[:tags]     = changes[:tags].reject(&:blank?).map(&:to_i) if changes.has_key?(:tags)

    flash[:notice] = ''
    flash[:error]  = ''

    # Pre-spawn checks; tags, project and owner
    if changes.has_key?(:tags)
      available_tags = current_user.available_tags.raw_first_column(:id)
      flash[:error] += "You do not have access to all tags you want to update.\n" unless
        (changes[:tags] - available_tags).blank?
      changes[:tags] &= available_tags
    end

    if (
      changes.has_key?(:group_id) &&
      ! current_user
        .assignable_groups
        .where(:id => changes[:group_id].to_i)
        .exists?
    )
      flash[:error] += "You do not have access to the project you want to update.\n"
      changes.delete(:group_id)
    end

    if (
      changes.has_key?(:user_id) &&
      ! current_user
        .available_users
        .where(:id => changes[:user_id].to_i)
        .exists?
    )
      flash[:error] += "You do not have access to the file owner you want to update.\n"
      changes.delete(:user_id)
    end

    # Ensure there is actually something left to update
    if file_ids.blank? || changes.blank?
      flash[:notice] += "Nothing to update.\n"
      redirect_to(params[:redirect_action] || { :action => :index })
      return
    end

    # Launch the update
    succeeded, failed = [], {}
    within_spawn = file_ids.size > 5
    CBRAIN.spawn_with_active_records_if(within_spawn, current_user, "Sending update to files") do
      # Read access is enough if just tags are to be updated
      access = changes.has_key?(:tags) && changes.keys.size == 1 ? :read : :write

      userfiles = Userfile
        .find_all_accessible_by_user(current_user, :access_requested => access)
        .where(:id => file_ids)

      userfiles = userfiles.where(:user_id => current_user.id) unless
        current_user.has_role?(:site_manager) || current_user.has_role?(:admin_user)

      # R/W access check
      failed["you don't have access"] = Userfile
        .where(:id => file_ids - userfiles.raw_first_column(:id))
        .select([:id, :name, :type])
        .all.to_a

      # Group access check
      if changes.has_key?(:group_id)
        allowed, rejected = User
          .where(:id => userfiles.pluck(:user_id).uniq)
          .all.partition do |user|
            user
              .assignable_group_ids
              .include?(changes[:group_id])
          end

        failed["new group is not accessible by the file's owner"] = userfiles
          .where(:user_id => rejected.map(&:id))
          .select([:id, :name, :type])
          .all.to_a

        userfiles = userfiles
          .where(:user_id => allowed.map(&:id))
      end

      # Dataprovider owner switch availability check
      if changes.has_key?(:user_id)
        allowed, rejected = DataProvider
          .where(:id => userfiles.pluck('userfiles.data_provider_id').uniq)
          .all.partition(&:allow_file_owner_change?)

        failed["changing file ownership is not allowed on this data provider"] = userfiles
          .where(:data_provider_id => rejected.map(&:id))
          .select([:id, :name, :type])
          .all.to_a

        userfiles = userfiles
          .where(:data_provider_id => allowed.map(&:id))
      end

      # Ensure boolean attributes have proper values
      [:group_writable, :hidden, :immutable].each do |attr|
        changes[attr] = (changes[attr].blank? ? 0 : 1) if changes.has_key?(attr)
      end

      # Extract tags, as they require special handling
      tags = changes.delete(:tags)

      userfiles.all.shuffle.each do |userfile|
        failure = "cannot update tags" if
          tags && ! userfile.set_tags_for_user(current_user, tags)

        failure = "cannot update attributes" if
          changes.present? && ! userfile.update_attributes_with_logging(changes, current_user, changes.keys)

        (failure ? (failed[failure] ||= []) : succeeded) << userfile
      end

      failed.reject! { |reason, files| files.blank? }

      # Async notification
      if within_spawn
        notice_message_sender("Update successful for file(s)", succeeded) if
          succeeded.present?

        error_message_sender("Update failed for file(s)", failed) if
          failed.present?
      end
    end

    # Sync notification
    if within_spawn
      flash[:notice] += "The files are being updated in background.\n"
    else
      flash[:notice] += "Update successful for #{view_pluralize(succeeded.count, "file")}.\n" if
        succeeded.present?

      flash[:error]  += "Update failed for #{view_pluralize(failed.sum { |k,v| v.size }, "file")}.\n" if
        failed.present?
    end

    redirect_to(params[:redirect_action] || { :action => :index })
  end

  def quality_control #:nodoc:
    @filelist = params[:file_ids] || []
  end

  def quality_control_panel #:nodoc:
    @filelist      = params[:file_ids] || []
    @current_index = params[:index]    || -1

    # This variable @target can be used by any custom QC viewer
    # to distinguish between the left and right side of the main
    # QC screen. The possible values are "qc_left_panel" and
    # "qc_right_panel"
    @target        = params[:target]   || ""

    @current_index = @current_index.to_i

    admin_user     = User.find_by_login("admin")
    everyone_group = Group.everyone

    pass_tag    = current_user.available_tags.find_or_create_by(
      :name     => "QC_PASS",
      :user_id  => admin_user.id,
      :group_id => everyone_group.id,
    )
    fail_tag    = current_user.available_tags.find_or_create_by(
      :name     => "QC_FAIL",
      :user_id  => admin_user.id,
      :group_id => everyone_group.id,
    )
    unknown_tag = current_user.available_tags.find_or_create_by(
      :name     => "QC_UNKNOWN",
      :user_id  => admin_user.id,
      :group_id => everyone_group.id,
    )

    commit_name  = extract_params_key([ :next, :previous, :pass, :fail, :unknown, :update ])
    if @current_index >=  0 && commit_name && commit_name != :next && commit_name != :previous
      @current_userfile = Userfile.find_accessible_by_user(@filelist[@current_index], current_user, :access_requested => :read)
      tag_ids = params[:tag_ids] || []
      case commit_name
        when :pass
          tag_ids |= [pass_tag.id.to_s]
        when :fail
          tag_ids |= [fail_tag.id.to_s]
        when :unknown
          tag_ids |= [unknown_tag.id.to_s]
      end
      @current_userfile.set_tags_for_user(current_user, tag_ids)
      # Only update description
      @current_userfile.update_attributes_with_logging( { "description" => params[:userfile][:description] }, current_user) if params[:userfile] && params[:userfile][:description]
    end

    if commit_name == :previous && @current_index > 0
      @current_index -= 1
    elsif @current_index < @filelist.size-1
      @current_index += 1
    end

    @userfile     = Userfile.find_accessible_by_user(@filelist[@current_index], current_user, :access_requested => :read)
    @qc_view_file = @userfile.view_path("qc_panel.html.erb").to_s # model-specific view partial, in its plugin directory
    if ! File.exists?(@qc_view_file)
      @qc_view_file = "userfiles/_default_qc_panel.html.erb" # default provided by cbrain
    end

    render :partial => "quality_control_panel"
  end

  #Create a collection from the selected files.
  def create_collection #:nodoc:
    filelist         = params[:file_ids]
    data_provider_id = params[:data_provider_id_for_collection]
    collection_name  = params[:collection_name]
    file_group       = current_assignable_project_id || current_user.own_group.id

    if data_provider_id.blank?
      flash[:error] = "No data provider selected.\n"
      redirect_to :action => :index
      return
    end

    # Handle collection name
    if collection_name.blank?
      suffix = Time.now.to_i
      while Userfile.where(:user_id => current_user.id, :name => "Collection-#{suffix}").first.present?
        suffix += 1
      end
      collection_name = "Collection-#{suffix}"
    end

    if ! Userfile.is_legal_filename?(collection_name)
      flash[:error] = "Error: collection name '#{collection_name}' is not acceptable (illegal characters?)."
      redirect_to :action => :index, :format =>  request.format.to_sym
      return
    end

    # Check if the collection name chosen by the user already exists for this user on the data_provider
    if current_user.userfiles.exists?(:name => collection_name, :data_provider_id => data_provider_id)
      flash[:error] = "Error: collection with name '#{collection_name}' already exists."
      redirect_to :action => :index, :format =>  request.format.to_sym
      return
    end

    if Userfile.find_accessible_by_user(filelist, current_user, :access_requested  => :read).count == 0
      flash[:error] = "Error: No accessible files selected."
      redirect_to :action => :index, :format =>  request.format.to_sym
      return
    end

    collection = FileCollection.new(
      :user_id          => current_user.id,
      :group_id         => file_group,
      :data_provider_id => data_provider_id,
      :name             => collection_name
    )

    CBRAIN.spawn_with_active_records(current_user,"Collection Merge") do
      begin
        userfiles = Userfile.find_accessible_by_user(filelist, current_user, :access_requested  => :read)
        result    = collection.merge_collections(userfiles)
        if result == :success
          Message.send_message(current_user,
                              :message_type  => :notice,
                              :header        => "Collections Merged",
                              :variable_text => "[[#{collection.name}][/userfiles/#{collection.id}]]"
                              )
          collection.addlog(self, "Created by #{current_user.login} by merging #{userfiles.size} files.")
        elsif result == :collision
          Message.send_message(current_user,
                              :message_type  => :error,
                              :header        => "Collection could not be merged.",
                              :variable_text => "There was a collision among the file names."
                              )
        end
      rescue => e
        Message.send_message(current_user,
                            :message_type  => :error,
                            :header        => "The collection was not created correctly on #{DataProvider.find_all_accessible_by_user(current_user).where( :id => data_provider_id, :online => true, :read_only => false ).first.name}",
                            :variable_text => "#{e.message}\n#{collection.name}\n"
                              )
      end
    end # spawn

    flash[:notice] = "Collection #{collection.name} is being created in background."
    redirect_to :action => :index

  end

  # Copy or move files to a new provider.
  def change_provider #:nodoc:

    # Destination provider
    data_provider_id = params[:data_provider_id_for_mv_cp]
    if data_provider_id.blank?
      flash[:error] = "No data provider selected.\n"
      redirect_to :action => :index
      return
    end

    # Option for move or copy.
    crush_destination = (params[:crush_destination].to_s =~ /crush/i) ? true : false

    # File list to apply operation
    filelist    = params[:file_ids] || []

    # Operaton to perform
    task       = extract_params_key([ :move, :copy ], "")
    word_move  = task == :move ? 'move'  : 'copy'
    word_moved = task == :move ? 'moved' : 'copied'

    new_provider    = DataProvider.find_all_accessible_by_user(current_user).where( :id => data_provider_id, :online => true, :read_only => false ).first
    unless new_provider
      flash[:error] = "Data provider #{data_provider_id} not accessible.\n"
      respond_to do |format|
        format.html { redirect_to :action => :index }
        format.json { render :json => { :error => flash[:error]}, :status => :forbidden }
        format.xml  { render :xml  => { :error => flash[:error]}, :status => :forbidden }
      end
      return
    end

    # Spawn subprocess to perform the move or copy operations
    success_list  = [] # [ id, id, id ]
    failed_list   = {} # { message1 => [id, id], message2 => [id, id] }
    CBRAIN.spawn_with_active_records_if(! api_request?, current_user, "#{word_move.capitalize} To Other Data Provider") do
      filelist.shuffle.each_with_index do |id,count|
        Process.setproctitle "#{word_move.capitalize} ID=#{id} #{count+1}/#{filelist.size} To #{new_provider.name}"
        begin
          u = Userfile.find_accessible_by_user(id, current_user, :access_requested => (task == :copy ? :read : :write) )
          next unless u
          orig_provider = u.data_provider
          next if orig_provider.id == data_provider_id # no support for copy to same provider in the interface, yet.
          res = nil
          if task == :move
            raise "not owner" unless u.has_owner_access?(current_user)
            res = u.provider_move_to_otherprovider(new_provider, :crush_destination => crush_destination)
          else # task is :copy
            my_group_id  = current_project ? current_assignable_project_id : current_user.own_group.id
            res = u.provider_copy_to_otherprovider(new_provider,
                     :user_id           => current_user.id,
                     :group_id          => my_group_id,
                     :crush_destination => crush_destination
                  )
          end
          raise "file collision: there is already such a file on the other provider" unless res
          success_list << u
        rescue => e
          if u.is_a?(Userfile)
            (failed_list[e.message] ||= []) << u
          else
            raise e
          end
        end
      end

      if success_list.present?
        notice_message_sender("Files #{word_moved} to #{new_provider.name}",success_list)
      end
      if failed_list.present?
        error_message_sender("Some files could not be #{word_moved} to #{new_provider.name}",failed_list)
      end
    end # spawn

    flash[:notice] = "Your files are being #{word_moved} in the background.\n"

    respond_to do |format|
        format.html { redirect_to :action => :index }
        format.json { render :json => { :success_list => success_list.map(&:id), :failed_list => failed_list.values.flatten.map(&:id) } }
    end
  end

  # Delete the selected files.
  def delete_files #:nodoc:
    filelist    = params[:file_ids] || []

    # Select all accessible files with write acces by the user.
    to_delete = Userfile.accessible_for_user(current_user, :access_requested => :write).where(:id => filelist)
    not_accessible_count = filelist.size - to_delete.count

    flash[:error] = "You do not have access to #{not_accessible_count} of #{filelist.size} file(s)." if not_accessible_count > 0

    # Delete in background
    deleted_success_list      = []
    unregistered_success_list = []
    failed_list               = {}
    CBRAIN.spawn_with_active_records_if(! api_request?, current_user, "Delete files") do
      idlist = to_delete.raw_first_column(:id).shuffle
      idlist.each_with_index do |userfile_id,count|
        userfile = Userfile.find(userfile_id) rescue nil # that way we instantiate one record at a time
        next unless userfile # in case it was destroyed externally
        Process.setproctitle "Delete ID=#{userfile.id} #{count+1}/#{idlist.size}"
        begin
          userfile.destroy
          deleted_success_list << userfile
        rescue => e
          (failed_list[e.message] ||= []) << userfile
        end
      end

      if deleted_success_list.present?
        notice_message_sender("Finished deleting file(s)",deleted_success_list)
      end
      if unregistered_success_list.present?
        notice_message_sender("Finished unregistering file(s)",unregistered_success_list)
      end
      if failed_list.present?
        error_message_sender("Error when deleting/unregistering file(s)",failed_list)
      end
    end # spawn

    flash[:notice] = "Your files are being deleted in background."

    if api_request?
      json_failed_list = {}
      failed_list.each do |error_message, userfiles|
        json_failed_list[error_message] = userfiles.map(&:id).sort
      end
    end

    respond_to do |format|
      format.html { redirect_to :action => :index }
      format.json { render :json => { :unregistered_list => unregistered_success_list.map(&:id).sort,
                                      :deleted_list      => deleted_success_list.map(&:id).sort,
                                      :failed_list       => json_failed_list,
                                      :error             => flash[:error]
                                    }
                  }
      format.xml  { render :xml  => { :unregistered_list => unregistered_success_list.map(&:id).sort,
                                      :deleted_list      => deleted_success_list.map(&:id).sort,
                                      :failed_list       => json_failed_list,
                                      :error             => flash[:error]
                                    }
                  }
    end
  end


  # Dowload the selected files.
  def download #:nodoc:

    # We do this verification explicitely because
    # we disable it in a skip_before_action (see top of file).
    # The reason is that otherwise Rails won't allow a POST
    # for an API client, which never provide the CSRF token.
    if ! api_request?
      verify_authenticity_token  # from Rails; will raise exception if not present.
    end

    filelist           = params[:file_ids] || []
    specified_filename = params[:specified_filename]

    # Check or build filename for downloaded data
    # Does NOT include .tar.gz extensions, which will be added later if necessary
    if ! specified_filename.blank?
      specified_filename.sub!(/(\.tar)?(\.g?z)?\z/i,"")
      if ! Userfile.is_legal_filename?(specified_filename)
          flash[:error] = "Error: filename '#{specified_filename}' is not acceptable (illegal characters?)."
          respond_to do |format|
            format.html { redirect_to :action => :index, :format =>  request.format.to_sym }
            format.json { render :json => { :error => flash[:error] } }
          end
          return
      end
    else
      is_blank  = true
      timestamp = Time.now.to_i.to_s[-4..-1]  # four digits long
      specified_filename = "cbrain_files_#{current_user.login}.#{timestamp}"
    end

    tot_size = 0

    # Find list of files accessible to the user
    userfiles_list = Userfile.find_accessible_by_user(filelist, current_user, :access_requested => :read)
    tot_size = userfiles_list.inject(0) { |total, u| total + (u.size || 0) }

    # Check size limit
    if tot_size > MAX_DOWNLOAD_MEGABYTES.megabytes
      flash[:error] = "You cannot download data that exceeds #{MAX_DOWNLOAD_MEGABYTES} megabytes using a browser.\n" +
                      "Consider using an externally accessible Data Provider (ask the admins for more info).\n"
      respond_to do |format|
          format.html { redirect_to :action => :index, :format =>  request.format.to_sym }
          format.json { render :json => { :error => flash[:error] } }
      end
      return
    end

    # Check duplicate names when downloading many files
    name_list = userfiles_list.map(&:name)
    if name_list.size != name_list.uniq.size
      flash[:error] = "Some files have the same names and cannot be downloaded together. Use separate downloads."
      respond_to do |format|
          format.html { redirect_to :action => :index, :format => request.format.to_sym }
          format.json { render :json => { :error => flash[:error] } }
      end
      return
    end

    # Sync all files
    failed_list = {}
    userfiles_list.each do |userfile|
      begin
        userfile.sync_to_cache
      rescue => e
        (failed_list[e.message] ||= []) << userfile
      end
    end
    if failed_list.present?
      error_message_sender("Error when syncing file(s)", failed_list);
      respond_to do |format|
          format.html { redirect_to :action => :index, :format =>  request.format.to_sym }
          format.json { render :json => { :error => flash[:error] } }
      end
      return
    end

    # When sending a single file, just throw it at the browser.
    if userfiles_list.size == 1 && userfiles_list[0].is_a?(SingleFile)
      userfile = userfiles_list[0]
      fullpath = userfile.cache_full_path
      send_file fullpath, :stream => true, :filename => is_blank ? fullpath.basename : specified_filename
      return
    end

    # When several files are to be sent, create and send a .tar.gz file
    tarfile      = create_relocatable_tar_for_userfiles(userfiles_list,current_user.login)
    tarfile_name = "#{specified_filename}.tar.gz"
    send_file tarfile, :stream  => true, :filename => tarfile_name
    CBRAIN.spawn_fully_independent("Download Clean Tmp #{current_user.login}") do
      sleep 3000
      File.delete(tarfile)
    end
  end

  #Extract a file from a collection and register it separately
  #in the database.
  def extract_from_collection #:nodoc:
    success = failure = 0

    unless params[:file_names] && params[:file_names].size > 0
      flash[:notice] = "No files selected for extraction"
      redirect_to :action  => :show
      return
    end

    collection       = FileCollection.find_accessible_by_user(params[:id], current_user, :access_requested  => :read)
    collection_path  = collection.cache_full_path
    data_provider    = collection.data_provider

    if data_provider.read_only?
      flash[:error] = "Unfortunately this file is located on a DataProvider that is not writable, so we can't extract its internal files."
      redirect_to :action => :show
      return
    end

    params[:file_names].each do |file|
      basename = File.basename(file)
      file_type = Userfile.suggested_file_type(basename) || SingleFile
      userfile = file_type.new(
          :name             => basename,
          :user_id          => current_user.id,
          :group_id         => collection.group_id,
          :data_provider_id => data_provider.id
      )
      Dir.chdir(collection_path.parent) do
        if userfile.save
          userfile.addlog("Extracted from collection '#{collection.name}'.")
          begin
            userfile.cache_copy_from_local_file(file)
            success += 1
          rescue
            userfile.data_provider_id = nil # nullifying will skip the provider_erase() in the destroy()
            userfile.destroy
            failure +=1
          end
        else
          failure += 1
        end
      end
      if success > 0
        flash[:notice] = "#{success} files were successfully extracted."
      end
      if failure > 0
        flash[:error] =  "#{failure} files could not be extracted."
      end
    end

    redirect_to :action  => :index
  end

  # Compress/archive a set of userfiles. Wrapper action for
  # +manage_compression+ with operation :compress.
  def compress #:nodoc:
    manage_compression(params[:file_ids] || [], :compress)
    respond_to do |format|
      format.html { redirect_to(:action => :index) }
      format.json { head :ok }
      format.xml  { head :ok }
    end
  end

  # Uncompress/unarchive a set of userfiles. Wrapper action for
  # +manage_compression+ with operation :uncompress.
  def uncompress #:nodoc:
    manage_compression(params[:file_ids] || [], :uncompress)
    respond_to do |format|
      format.html { redirect_to(:action => :index) }
      format.json { head :ok }
      format.xml  { head :ok }
    end
  end

  # Given a set of files selected by the user, creates a new
  # file of type CbrainFileList the describe them; the file is
  # added automatically to the user's workspace.
  def export_file_list
    file_ids = params[:file_ids] || []

    dest_dp_id   = DataProvider.find_by_id(current_user.meta["pref_data_provider_id"]).try(:id)
    dest_dp_id ||= DataProvider.find_all_accessible_by_user(current_user).where(:online => true).first.try(:id)

    if !dest_dp_id
      flash[:error] = "For this feature to work you need access to an online Data Provider; you can select " +
                      "your favorite one in your account preferences."
      redirect_to(:action => :index)
      return
    end

    # Find the files
    userfiles = Userfile
      .find_all_accessible_by_user(current_user, :access_requested => :read)
      .where(:id => file_ids).all.to_a

    if userfiles.empty?
      flash[:error] = "You need to select some files first."
      redirect_to(:action => :index)
      return
    end

    # Create the new file list
    file_list = CbrainFileList.new(
      :user_id          => current_user.id,
      :group_id         => current_assignable_project_id || current_user.own_group.id,
      :name             => "file_list.#{Process.pid}.#{Time.now.to_i}.cbcsv",
      :data_provider_id => dest_dp_id,
    )

    # Save it and set its content.
    if file_list.save
      csv_text = CbrainFileList.create_csv_file_from_userfiles(userfiles)
      file_list.cache_writehandle { |fh| fh.write(csv_text) }
      flash[:notice] = "Created file list named '#{file_list.name}'."
      redirect_to(:controller => :userfiles, :action => :show, :id => file_list.id)
    else
      flash[:error] = "Could not create file list. Contact the admins."
      redirect_to(:action => :index)
    end

  end

  # Compress/uncompress single files (SingleFile) and archive/unarchive
  # collections (FileCollection). This method changes the compression status
  # (compressed/archived, uncompressed/unarchived) of a set of userfile IDs
  # +file_ids+. To compress (default) specify +operation+ as :compress and
  # to uncompress specify +operation+ as :uncompress.
  # Note that this method internally handles all status messages using +flash+.
  def manage_compression(file_ids, operation = :compress) #:nodoc:
    compressing = (operation == :compress)

    skipped = {}
    userfiles = Userfile
      .find_all_accessible_by_user(current_user, :access_requested => :write)
      .where(:id => file_ids)

    # Write access to the userfiles' DP is required
    readonly_dps, writable_dps = DataProvider
      .where(:id => userfiles.pluck('userfiles.data_provider_id').uniq)
      .all.partition(&:read_only?)

    skipped["Data Provider not writable"] = userfiles
      .where(:data_provider_id => readonly_dps.map(&:id))
      .count

    userfiles = userfiles
      .where(:data_provider_id => writable_dps)

    # Check for SingleFile filename collisions
    # FIXME assuming the RDBMS supports CONCAT, LEFT & LENGTH...
    if compressing
      collide = "CONCAT(userfiles.name, '.gz')"
      match   = "userfiles.name NOT LIKE '%.gz'"
    else
      collide = "LEFT(userfiles.name, LENGTH(userfiles.name) - LENGTH('.gz'))"
      match   = "userfiles.name LIKE '%.gz'"
    end

    collisions = userfiles
      .joins(<<-"SQL".strip_heredoc)
        INNER JOIN userfiles AS collisions ON (
          collisions.user_id          = userfiles.user_id AND
          collisions.data_provider_id = userfiles.data_provider_id AND
          collisions.name             = #{collide}
        )
      SQL
      .where(match)
      .select(['userfiles.id', 'userfiles.name', 'userfiles.type'])
      .all.to_a
      .select { |userfile| userfile.is_a?(SingleFile) }

    skipped["Filename collision"] = collisions.count
    userfiles = userfiles.where('userfiles.id NOT IN (?)', collisions.map(&:id)) unless
      collisions.blank?

    # Skipped files notification
    flash[:error] = skipped
      .reject { |reason, count| count == 0 }
      .map { |reason, count| "#{count} files skipped: #{reason}" }
      .join('\n')

    # Ensure there is actually something left to compress/uncompress
    if userfiles.count == 0
      flash[:notice] = "Nothing to #{operation.to_s}"
      return
    end

    # Start compressing/uncompressing
    CBRAIN.spawn_with_active_records(current_user, operation.to_s.humanize) do
      succeeded, failed = [], {}

      userfiles_list = userfiles.all.shuffle # real array of all records
      count_todo     = userfiles_list.size
      userfiles_list.each_with_index do |userfile,idx|

        if userfile.immutable?
          ( failed['File is immutable.'] ||= [] ) << userfile
          next
        end

        # This begin block process each file and captures exceptions
        # to provide a report of failures.
        begin

          # SingleFiles
          if userfile.is_a?(SingleFile)
            Process.setproctitle "GzipFile ID=#{userfile.id} #{idx+1}/#{count_todo}"
            userfile.gzip_content(operation) # :compress or :uncompress
            next
          end

          # FileCollections
          if compressing && ! userfile.archived?
            Process.setproctitle "ArchiveFile ID=#{userfile.id} #{idx+1}/#{count_todo}"
            failure = userfile.provider_archive
          elsif ! compressing && userfile.archived?
            Process.setproctitle "UnarchiveFile ID=#{userfile.id} #{idx+1}/#{count_todo}"
            failure = userfile.provider_unarchive
          end
          raise failure unless failure.blank?
          succeeded << userfile

        rescue => e
          (failed[e.message] ||= []) << userfile
        end
      end

      # Async notification
      notice_message_sender("Finished #{operation.to_s}ing file(s)", succeeded) if
        succeeded.present?

      error_message_sender("Error when #{operation.to_s}ing file(s)", failed) if
        failed.present?
    end

    flash[:notice] = "#{view_pluralize(userfiles.count, "file")} being #{operation.to_s}ed in background.\n"
  end

  # Guess the type of a file from a given filename. Thin XML/JSON API wrapper
  # around SingleFile.suggested_file_type.
  def detect_file_type
    @type = (SingleFile.suggested_file_type(params[:file_name]) || SingleFile).name
    respond_to do |format|
      format.html { render :html => @type.html_safe }
      format.json { render :json => { :type => @type } }
      format.xml  { render :xml  => { :type => @type } }
    end
  end

  private

  def userfile_params #:nodoc:
    params.require(:userfile).permit(
      :name, :size, :user_id, :parent_id, :type, :group_id, :data_provider_id,
      :group_writable, :num_files, :hidden, :immutable, :description, :tag_ids => []
    )
  end

  # Verify that all files selected for an operation
  # are accessible by the current user.
  def permission_check #:nodoc:

    if params[:file_ids].blank?
      flash[:error] = "No files selected? Selection cleared.\n"
      redirect_to :action => :index
      return
    end

    yield
  rescue ActiveRecord::RecordNotFound
    flash[:error]  += "\n" unless flash[:error].blank?
    flash[:error] ||= ""
    flash[:error]  += "You don't have appropriate permissions to apply the selected action to this set of files."

    redirect_to :action => :index
  end

  #Extract files from an archive and register them in the database.
  #+archive_file_name+ is a path to an archive file (tar or zip).
  #+attributes+ is a hash of attributes for all the files,
  #they must contain at least user_id and data_provider_id
  def extract_from_archive(archive_file_name, file_type = nil, attributes = {}) #:nodoc:

    file_type = SingleFile if file_type.present? && ! (file_type <= SingleFile) # just protect from classes outside of Userfile
    escaped_archivefile = archive_file_name.to_s.bash_escape # bash escaping

    # Check for required attributes
    data_provider_id    = attributes["data_provider_id"] ||
                          attributes[:data_provider_id]
    cb_error "No data provider ID supplied." unless data_provider_id

    user_id             = attributes["user_id"]  ||
                          attributes[:user_id]
    cb_error "No user ID supplied." unless user_id

    # Create content list
    all_files        = []
    if archive_file_name =~ /(\.tar.gz|\.tgz)\z/i
      all_files = IO.popen("tar -tzf #{escaped_archivefile}") { |fh| fh.readlines.map(&:chomp) }
    elsif archive_file_name =~ /\.tar\z/i
      all_files = IO.popen("tar -tf #{escaped_archivefile}") { |fh| fh.readlines.map(&:chomp) }
    elsif archive_file_name =~ /\.zip/i
      all_files = IO.popen("unzip -l #{escaped_archivefile}") { |fh| fh.readlines.map(&:chomp)[3..-3].map{ |line|  line.split[3]} }
    else
      cb_error "Cannot process file with unknown extension: #{archive_file_name}"
    end

    count = all_files.select{ |f| f !~ /\// }.size

    #max of 50 files can be added to the file list at a time.
    cb_error "Overflow: more than 50 files found in archive." if count > 50

    workdir = "/tmp/filecollection.#{Process.pid}"
    Dir.mkdir(workdir)
    Dir.chdir(workdir) do
      if archive_file_name =~ /(\.tar.gz|\.tgz)\z/i
        system("tar -xzf #{escaped_archivefile}")
      elsif archive_file_name =~ /\.tar\z/i
        system("tar -xf #{escaped_archivefile}")
      elsif archive_file_name =~ /\.zip/i
        system("unzip #{escaped_archivefile}")
      else
        FileUtils.remove_dir(workdir, true)
        cb_error "Cannot process file with unknown extension: #{archive_file_name}"
      end
    end

    # Prepare for extraction
    status           = :success
    successful_files = []
    failed_files     = []
    nested_files     = []

    all_files.each do |file_name|
      if file_name =~ /\//
        nested_files << file_name
      elsif Userfile.where(
              :name             => file_name,
              :user_id          => user_id,
              :data_provider_id => data_provider_id
            ).first
        failed_files << file_name
      else
        successful_files << file_name
      end
    end

    Dir.chdir(workdir) do
      successful_files.each do |file|
        local_file_type = file_type || Userfile.suggested_file_type(file)
        u = local_file_type.new(attributes)
        u.name = file
        if u.save
          u.cache_copy_from_local_file(file)
          u.size = File.size(file)
          u.save
        else
          status = :failed
        end
      end
    end

    FileUtils.remove_dir(workdir, true)

    # Report these values using new comm mechanism
    # [status, successful_files, failed_files, nested_files]
    report = "Based on the content of the archive we found:\n" +
             "#{successful_files.size.to_s} files successfully extracted;\n" +
             "#{failed_files.size.to_s} files failed extracting;\n" +
             "#{nested_files.size.to_s} files were ignored because they are nested in subdirectories.\n"
    if status == :success && failed_files.size == 0 && nested_files.size == 0
      Message.send_message(current_user.own_group,
        :message_type  => 'notice',
        :header  => "File extraction completed",
        :description  => "Your files have been extracted from archive '#{archive_file_name}'",
        :variable_text  => report
      )
    else
      Message.send_message(current_user.own_group,
        :message_type  => 'error',
        :header  => "File extraction failed",
        :description  => "Some errors occurred while extracting files from archive '#{archive_file_name}'",
        :variable_text  => report
      )
    end

  end

  # This method creates a tar file of the userfiles listed
  # in +ulist+ (an array of Userfiles). Each userfile is at
  # the top of the tar file, so this means that the tar file
  # could include multiple entries with the same name at the top.
  # TODO: FIXME . Not sure how to fix.
  #
  # Note on the name of the method: a previous version tried to
  # create a symlink structure, but that transferred hte values of
  # all symbolic links internal to the userfiles on LINUX.
  # See also: the -H option of tar on MacOS X which would do the trick,
  # but doesn't exist on LINUX.
  def create_relocatable_tar_for_userfiles(ulist,username) #:nodoc:
    timestamp    = sprintf("%6.6d",rand(1000000)) # six digits long
    tarfilename  = Pathname.new("/tmp/cbrain_files_#{username}.#{timestamp}.tar.gz") # must be outside the tmp work dir
    errfile      = Pathname.new("/tmp/tar.#{Process.pid}.#{timestamp}.stderr")

    tar_cd_arg_list = []; # properly escaped list of args for the tar command
    ulist.each do |u|
      fullpath = u.cache_full_path
      basename = fullpath.basename
      dirname  = fullpath.dirname
      tar_cd_arg_list << "-C"
      tar_cd_arg_list << dirname.to_s.bash_escape
      tar_cd_arg_list << basename.to_s.bash_escape
    end

    system("tar -cf - #{tar_cd_arg_list.join(" ")} 2> #{errfile.to_s.bash_escape} | gzip -c > #{tarfilename.to_s.bash_escape}")
    err = File.read(errfile) rescue "Oops, the error file has disappeared..."
    cb_error "Error creating the download file. The file list might be too long, or some files are missing. Sorry." if err.present?

    return tarfilename
  ensure
    File.unlink(errfile) rescue nil
  end

  # Sort a list of files in "tree order" where
  # parents are listed just before their children.
  # It also keeps the original list's ordering
  # at each level. The method will set the level
  # of the files too, with 0 for the top level.
  #
  # The records processed here are not userfiles,
  # instead they are small arrays, originally with two
  # entries:
  #
  #   [ userfile_id, parent_id ]
  #
  # At the end, they get extended to five entries each:
  #
  #   [ userfile_id, parent_id, [ child1_id, child2_id... ], orig_idx, level ]
  def tree_sort_by_pairs(pairs = [])  # array of pairs: [ [ id, parent_id ], [ id, parent_id ] ... ]
    top         = [ nil, 999_999_999 ] # Dummy, to collect top level; ID is NIL!
    userfiles   = Array(pairs) + [ top ] # Note: so that by_id[nil] returns 'top'

    by_id       = {}        # id => userfile
    userfiles.each_with_index do |u,idx|
      u[2]        = nil
      by_id[u[0]] = u   # WE NEED TO USE THIS INSTEAD OF .parent !!!
      u[3]        = idx # original order in array
    end

    # Construct tree
    seen      = {}
    userfiles.each do |file|
      current  = file # probably not necessary
      track_id = file[0] # to detect loops
      while ! seen[current[0]]
        break if current == top
        seen[current[0]] = track_id
        parent_id     = current[1] # Can be nil! by_id[nil] will return 'top'
        parent        = by_id[parent_id] # Cannot use current.parent, as this would destroy its :tree_children
        parent      ||= top
        break if seen[parent[0]] && seen[parent[0]] == track_id # loop
        parent[2] ||= []
        parent[2] << current
        current = parent
      end
    end

    # Flatten tree
    all_tree_children_by_pairs(top,0) # sets top children's levels to '0'
  end

  # Returns an array will all children or subchildren
  # of the userfile, as contructed by tree_sort.
  # Optionally, sets the :level pseudo attribute
  # to all current children, increasing it down
  # the tree.
  def all_tree_children_by_pairs(top,level = nil) #:nodoc:
    return [] if top[2].blank?
    result = []
    top[2].sort { |a,b| a[3] <=> b[3] }.each do |child|
      child[4] = level if level
      result << child
      if child[2] # the 'if' optimizes one recursion out
        all_tree_children_by_pairs(child, level ? level+1 : nil).each { |c| result << c } # amazing! faster than += for arrays!
      end
    end
    result
  end

  # Base userfiles scope; all userfiles currently visible to the user,
  # respecting view options, user and project restrictions.
  # Requires a valid @scope object.
  def base_scope
    base = Userfile.where(nil)

    # Restrict by 'view all' or not
    @scope.custom[:view_all] = !current_user.has_role?(:admin_user) if
      @scope.custom[:view_all].nil?

    if ((! api_request?) && (@scope.custom[:view_all] == "false" || !@scope.custom[:view_all]))
      base = base.where(:user_id => current_user.id)
    else # api request, or view_all is true
      base = Userfile.restrict_access_on_query(current_user, base, :access_requested => :read)
    end

    base = base.where(:group_id => current_project.id) if current_project
    base
  end

  # Custom filters scope; filtered list of userfiles respecting currently active
  # custom filters. +base+ is expected to be the initial scope to apply custom
  # filters to (defaults to +base_scope+). Requires a valid @scope object.
  def custom_scope(base = nil)
    (@scope.custom[:custom_filters] ||= []).map!(&:to_i)
    (@scope.custom[:custom_filters] &= current_user.custom_filter_ids)
      .map { |id| UserfileCustomFilter.find_by_id(id) }
      .compact
      .inject(base || base_scope) { |scope, filter| filter.filter_scope(scope) }
  end

  # Combination of +base_scope+, +custom_scope+ and @scope object; returns a
  # scoped list of userfiles filtered/ordered by all three.
  # Requires a valid @scope object.
  def filtered_scope
    userfiles = custom_scope(base_scope)
    userfiles = userfiles.where(:hidden => false) unless
      @scope.custom[:view_hidden]

    @scope.apply(userfiles)
  end

  # Userfiles-specific tag Scope filter; filter by a set of tags which must
  # all be on a given userfile for it to pass the filter. Note that this is
  # an all-or-nothing filter; to pass, an userfile needs *all* tags.
  #
  # Note that this filter uses Scope::Filter's *value* attribute to hold the
  # tags to check against, and that the *attribute* attribute is statically
  # set to 'tags' (as this filter will only ever filter tags).
  class TagFilter < Scope::Filter
    # Create a new blank TagFilter. Only present to pre-set *attribute*.
    def initialize #:nodoc:
      @attribute = 'tags'
    end

    # Nice string representation of this filter for +pretty_scope_filter+.
    def to_s
      "Tags: " + Tag.find(@value).map(&:name).uniq.join(', ') rescue ''
    end

    # The methods below are TagFilter specific versions of the Scope::Filter
    # interface. See Scope::Filter for more details on how these methods
    # operate and for detailed parameter information.

    # Type name to recognize this filter when in hash representation
    # (+type+ (+t+) key).
    def self.type_name
      'uf.tags'
    end

    # Apply this filter on +collection+, which is expected to be a userfiles
    # model or scope or a collection of Userfile objects.
    #
    # Note that this filter is specific to Userfiles and will not operate
    # correctly with any other kind of object.
    def apply(collection)
      raise "no tags to filter with" unless @value.present?
      tags = Set.new(@value)

      # With an Userfile model (or scope)
      if (collection <= ApplicationRecord rescue nil)
        placeholders = tags.map { '?' }.join(',')
        collection.where(<<-"SQL".strip_heredoc, *tags)
          ((
            SELECT COUNT(DISTINCT tags_userfiles.tag_id)
            FROM tags_userfiles
            WHERE
              tags_userfiles.userfile_id = userfiles.id AND
              tags_userfiles.tag_id IN (#{placeholders})
          ) = #{tags.size})
        SQL

      # With a Ruby Enumerable
      else
        collection.select { |u| (tags - u.tags.map(&:id)).empty? }
      end
    end

    # Check if this filter is valid (+apply+ can be used). A TagFilter only
    # requires a valid *value* to be useable.
    def valid?
      @value.present?
    end

    # Create a new TagFilter from a hash representation. The following keys
    # are recognized in +hash+:
    #
    # [+value+ or +v+]
    #  *value* attribute: an Enumerable of tags (tag IDs as integers) for the
    #  userfiles to have.
    #
    # Note that no other key from Scope::Filter's +from_hash+ is recognized.
    def self.from_hash(hash)
        return nil unless hash.is_a?(Hash)

        hash = hash.with_indifferent_access unless
          hash.is_a?(HashWithIndifferentAccess)

        filter = self.new
        filter.value = Array(hash['value'] || hash['v'])
          .map { |v| Integer(v) rescue nil }
          .compact

        filter
    end

    # Convert this TagFilter into a hash representation, doing the exact
    # opposite of +from_hash+.
    def to_hash(compact: false)
      hash = {
        'type'  => self.class.type_name,
        'value' => @value
      }

      compact ? self.class.compact_hash(hash) : hash
    end

    # Compact +hash+, a hash representation of TagFilter (matching +from_hash+'s
    # structure).
    def self.compact_hash(hash)
      ViewScopes::Scope.generic_compact_hash(
        hash,
        {
          'type'  => 't',
          'value' => 'v',
        },
        defaults: { 'value' => [] }
      )
    end
  end

  # Crude Userfiles-specific child/parent relationship Scope filter; filter by
  # whether or not a given userfile has children or a parent.
  #
  # Note that this filter uses Scope::Filter's *operator* attribute to hold
  # which condition to filter on, and that the *attribute* attribute is set
  # accordingly to avoid duplication. The following conditions (values for
  # *operator*) are available:
  # [+no_child+]  Userfiles without any children (shortened to 'c').
  # [+no_parent+] Userfiles without a parent (shortened to 'p').
  class HierarchyFilter < Scope::Filter
    # Nice string representation of this filter for +pretty_scope_filter+.
    def to_s
      case @operator.to_s
      when 'no_child'  then 'Has no children'
      when 'no_parent' then 'Has no parent'
      else @operator.to_s.humanize
      end
    end

    # The methods below are HierarchyFilter specific versions of the
    # Scope::Filter interface. See Scope::Filter for more details on how these
    # methods operate and for detailed parameter information.

    # Type name to recognize this filter when in hash representation
    # (+type+ (+t+) key).
    def self.type_name
      'uf.hier'
    end

    # Apply this filter on +collection+, which is expected to be a userfiles
    # model or scope or a collection of Userfile objects.
    #
    # Note that this filter is specific to Userfiles and will not operate
    # correctly with any other kind of object.
    def apply(collection)
      raise "nothing to filter with" unless valid?

      # With an Userfile model (or scope)
      if (collection <= ApplicationRecord rescue nil)
        case @operator.to_s.downcase
        when 'no_child'
          collection.where(<<-"SQL".strip_heredoc)
            (NOT EXISTS(
              SELECT 1
              FROM userfiles AS children
              WHERE children.parent_id = userfiles.id
            ))
          SQL
        when 'no_parent'
          collection.where(:parent_id => nil)
        end

      # With a Ruby Enumerable
      else
        case @operator.to_s.downcase
        when 'no_child'
          collection.select { |u| u.children.exists? }
        when 'no_parent'
          collection.reject(&:parent_id)
        end
      end
    end

    # Check if this filter is valid (+apply+ can be used). A HierarchyFilter
    # only requires a valid *operator*.
    def valid?
      ['no_child', 'no_parent'].include?(@operator.to_s)
    end

    # Create a new HierarchyFilter from a hash representation. The following
    # keys are recognized in +hash+:
    #
    # [+operator+ or +o+]
    #  *operator* attribute: either no_child/c or no_parent/p
    #
    # Note that no other key from Scope::Filter's +from_hash+ is recognized.
    def self.from_hash(hash)
      return nil unless hash.is_a?(Hash)

      hash = hash.with_indifferent_access unless
        hash.is_a?(HashWithIndifferentAccess)

      filter = self.new

      operator = (hash['operator'] || hash['o'] || 'no_child').to_s.downcase
      filter.operator  = operator if ['no_child', 'no_parent'].include?(operator)
      filter.attribute = "##{filter.operator}" if filter.operator

      filter
    end

    # Convert this HierarchyFilter into a hash representation, doing the exact
    # opposite of +from_hash+.
    def to_hash(compact: false)
      hash = {
        'type'     => self.class.type_name,
        'operator' => @operator.to_s
      }

      compact ? self.class.compact_hash(hash) : hash
    end

    # Compact +hash+, a hash representation of HierarchyFilter (matching
    # +from_hash+'s structure).
    def self.compact_hash(hash)
      ViewScopes::Scope.generic_compact_hash(
        hash,
        {
          'type'     => 't',
          'operator' => 'o',
        },
        defaults: { 'operator' => 'no_child' },
        values: [
          [ 'operator', 'no_child'  => 'c' ],
          [ 'operator', 'no_parent' => 'p' ]
        ]
      )
    end
  end

end
