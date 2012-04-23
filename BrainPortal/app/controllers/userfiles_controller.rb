
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

#RESTful controller for the Userfile resource.
class UserfilesController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__]

  api_available

  before_filter :login_required
  before_filter :auto_add_persistent_userfile_ids, :except => [ :manage_persistent ]
  around_filter :permission_check, :only => [
      :download, :update_multiple, :delete_files, :create_collection, :change_provider, :quality_control,
      :manage_persistent
  ]

  MAX_DOWNLOAD_MEGABYTES = 400

  # GET /userfiles
  # GET /userfiles.xml
  def index #:nodoc:
    #------------------------------
    # Filtered scope
    #------------------------------

    # Prepare filters
    @filter_params["filter_hash"]                 ||= {}
    @filter_params["filter_custom_filters_array"] ||= []
    @filter_params["filter_custom_filters_array"] &= current_user.custom_filter_ids.map(&:to_s)  
    @filter_params["filter_tags_array"]           ||= [] 
    @filter_params["filter_tags_array"]           &= current_user.available_tags.map{ |t| t.id.to_s }  
    @filter_params["sort_hash"]["order"] ||= 'userfiles.name'
   
    # Prepare custom filters
    custom_filter_tags = @filter_params["filter_custom_filters_array"].map { |filter| UserfileCustomFilter.find(filter).tag_ids }.flatten.uniq
        
    # Prepare tag filters
    tag_filters    = @filter_params["filter_tags_array"] + custom_filter_tags
    
    @header_scope = Userfile.scoped
    # Restrict by 'view all' or not
    
    @filter_params["view_all"] ||= 'on'
    if @filter_params["view_all"] == 'on'
      @header_scope = Userfile.restrict_access_on_query(current_user, @header_scope, :access_requested => :read)
    else
      @header_scope = @header_scope.where( :user_id => current_user.id )
    end
    
    # Filter by current project
    if current_project
      @header_scope = @header_scope.where( :group_id  => current_project.id )
    end
    
    
    
    #Apply filters
    @filtered_scope = base_filtered_scope(@header_scope)
    
    @filter_params["filter_custom_filters_array"].each do |custom_filter_id|
      custom_filter = UserfileCustomFilter.find(custom_filter_id)
      @filtered_scope = custom_filter.filter_scope(@filtered_scope)
    end
    
    unless tag_filters.blank?
      @filtered_scope = @filtered_scope.where( "((SELECT COUNT(DISTINCT tags_userfiles.tag_id) FROM tags_userfiles WHERE tags_userfiles.userfile_id = userfiles.id AND tags_userfiles.tag_id IN (#{tag_filters.join(",")})) = #{tag_filters.size})" )
    end
    
    #------------------------------
    # Sorting scope
    #------------------------------

    sorted_scope = base_sorted_scope @filtered_scope.where( :format_source_id => nil )
    
    tags_and_total_counts = @header_scope.select("tags.name as tag_name, tags.id as tag_id, COUNT(tags.name) as tag_count").joins(:tags).group("tags.name")
    filt_tag_counts       = @filtered_scope.joins(:tags).group("tags.name").count
    @tag_filters          = tags_and_total_counts.map { |tc| ["#{tc.tag_name} (#{filt_tag_counts[tc.tag_name].to_i}/#{tc.tag_count})", { :parameter  => :filter_tags_array, :value => tc.tag_id, :class => "#{"filter_zero" if filt_tag_counts[tc.tag_name].blank?}" }]  }
    
    # Identify and add necessary table joins
    joins = []
    sort_table = @filter_params["sort_hash"]["order"].split(".")[0]
    if sort_table == "users" || current_user.has_role?(:site_manager)
      joins << :user
    end
    case sort_table
    when "groups"
      joins << :group
    when "data_providers"
      joins << :data_provider
    end
    sorted_scope = sorted_scope.joins(joins) unless joins.empty?

    # Add a secondary sorting column (name)
    sorted_scope = sorted_scope.order(:name) unless @filter_params["sort_hash"]["order"] == 'userfiles.name'

    # For Pagination
    unless [:html, :js].include?(request.format.to_sym)
      @per_page = 999_999_999
    end
    offset = (@current_page - 1) * @per_page

    #------------------------------
    # Final paginated array of objects
    #------------------------------

    includes = [ :user, :data_provider, :sync_status, :tags, :group ] # used only when fetching objects for rendering the page

    # ---- NO tree sort ----
    @filter_params["tree_sort"] = "on" if @filter_params["tree_sort"].blank?
    if @filter_params["tree_sort"] == "off" || ![:html, :js].include?(request.format.to_sym)
      @filtered_scope  = @filtered_scope.scoped( :joins => :user ) if current_user.has_role?(:site_manager)
      @userfiles_total = @filtered_scope.size
      ordered_real  = sorted_scope.includes(includes - joins).offset(offset).limit(@per_page).all
    # ---- WITH tree sort ----
    else
      # We first get a list of 'simple' objects [ id, parent_id ]
      simple_pairs      = sorted_scope.raw_rows( [ "userfiles.id", "userfiles.parent_id" ] )
      simple_pairs      = tree_sort_by_pairs(simple_pairs) # private method in this controller
      # At this point, each simple_pair is [ userfile_id, parent_id, [ child1_id, child2_id... ], orig_idx, level ]
      @userfiles_total  = simple_pairs.size
      if params[:find_file_id]
        find_file_id    = params[:find_file_id].to_i
        find_file_index = simple_pairs.index { |u| u[0] == find_file_id }
        if find_file_index
          @current_page = (find_file_index / @per_page) + 1
          offset = (@current_page - 1) * @per_page
        end
      end

      # Paginate the list of simple objects
      page_of_userfiles = simple_pairs[offset, @per_page] || []
      
      # Fetch the real objects and collect them in the same order
      userfile_ids      = page_of_userfiles.collect { |u| u[0] }
      real_subset       = @filtered_scope.includes( includes ).where( :id => userfile_ids )
      real_subset_index = real_subset.index_by { |u| u.id }
      ordered_real      = []
      page_of_userfiles.each do |simple|
        full = real_subset_index[simple[0]]
        next unless full # this can happen when the userfile list change between fetching the simple and real lists
        full.level = simple[4]
        ordered_real << full
      end
      
    end

    # Turn the array ordered_real into the final paginated collection
    @userfiles = WillPaginate::Collection.create(@current_page, @per_page) do |pager|
      pager.replace(ordered_real || [])
      pager.total_entries = @userfiles_total
      pager
    end

    respond_to do |format|
      format.html
      format.js
      format.xml  { render :xml => @userfiles }
      format.csv
    end
  end

  def new_parent_child #:nodoc:

    file_ids   = params[:file_ids]
    @userfiles = Userfile.find_all_accessible_by_user(current_user, :access_requested => :write).where(:id => file_ids).all
    if @userfiles.size < 2 
      render :text  => "<span class=\"warning\">You must select at least two files to which you have write access.</span>"
      return
    end
    
    render :action  => :new_parent_child, :layout  => false
  end
  
  def create_parent_child #:nodoc:
    parent_id = params[:parent_id]
    child_ids = params[:child_ids]
    
    if parent_id.blank? || child_ids.blank?
      flash[:error] = "Must have both parent and children selected for this operation."
    else
      child_ids.delete(parent_id)
      @children = Userfile.find_accessible_by_user(params[:child_ids], current_user)
      @parent   = Userfile.find_accessible_by_user(params[:parent_id], current_user)
      @children.each { |c| c.move_to_child_of(@parent) }
    end
    
    redirect_to :action => :index
  end

  #####################################################
  # Tranfer contents of a file.
  # If no relevant parameters are given, the controller
  # will simply attempt to send the entire file.
  # Otherwise, it will modify it's response according
  # to the following parameters:
  # [:content_loader] a content loader defined for the
  #                   userfile.
  # [:arguments]      arguments to pass to the content
  #                   loader method.
  #####################################################
  #GET /userfiles/1/content?option1=....optionN=...
  def content
    @userfile = Userfile.find_accessible_by_user(params[:id], current_user, :access_requested => :read)
    
    content_loader = @userfile.find_content_loader(params[:content_loader])
    argument_list = params[:arguments] || []
    argument_list = [argument_list] unless argument_list.is_a?(Array)
 
    if content_loader
      response_content = @userfile.send(content_loader.method, *argument_list)
      if content_loader.type == :send_file
        send_file response_content
      elsif content_loader.type == :gzip
        response.headers["Content-Encoding"] = "gzip" 
        render :text => response_content
      else
        render content_loader.type => response_content
      end
    else
      @userfile.sync_to_cache
      send_file @userfile.cache_full_path, :stream => true, :filename => @userfile.name
    end
  rescue
    render :file => "public/404.html", :status => 404
  end
  
  def display
    @userfile = Userfile.find_accessible_by_user(params[:id], current_user, :access_requested => :read)
    viewer_name = params[:viewer]
    viewer      = @userfile.find_viewer(viewer_name)
    if viewer
      @partial = viewer.partial
    elsif viewer_name =~ /[\w\/]+/
      viewer_path = viewer_name.split("/")
      viewer_name = viewer_path.pop
      if File.exists?(Rails.root.to_s + "/app/views/userfiles/viewers/#{viewer_path.join("/")}/_#{viewer_name}.#{request.format.to_sym}.erb")      
        @partial = viewer_path.push(viewer_name).join("/")
      end
    end
    
    begin
      if @partial
        if params[:apply_div] == "false"
          render :partial  => "userfiles/viewers/#{@partial}"
        else
          render :action  => :display, :layout  => false
        end
      else
        render :text => "<div class=\"warning\">Could not find viewer #{params[:viewer]}.</div>", :status  => "404"
      end
    rescue
      render :text => "<div class=\"warning\">Error generating view code for viewer #{params[:viewer]}.</div>", :status => "404"
    end
  end
  
  def show #:nodoc:
    @userfile = Userfile.find_accessible_by_user(params[:id], current_user, :access_requested => :read)
    
    # This allows the user to manually trigger the syncing to the Portal's cache
    @sync_status = 'ProvNewer' # same terminology as in SyncStatus
    state = @userfile.local_sync_status
    @sync_status = state.status if state
    @default_viewer = @userfile.viewers.first

    @log  = @userfile.getlog rescue nil

    respond_to do |format|
      format.html
      format.xml  { render :xml => @userfile }
    end
  end
  
  def new #:nodoc:
    @user_tags      = current_user.available_tags
    @data_providers = DataProvider.find_all_accessible_by_user(current_user).all
    @data_providers.reject! { |dp| dp.meta[:no_uploads].present? }
    render :partial => "new"
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
      @userfiles.each do |userfile|
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

    if @userfiles.size == 1 && params[:back_to_show_page]
      redirect_to :controller => :userfiles, :action  => :show, :id => @userfiles[0].id
    else
      redirect_to :action  => :index
    end
  end

  # POST /userfiles
  # POST /userfiles.xml

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
    params[:userfile] ||= {}
    
    file_type_name      = params[:file_type].presence || 'SingleFile'
    file_type           = file_type_name.constantize rescue SingleFile
    file_type           = SingleFile unless file_type < Userfile

    redirect_path = params[:redirect_to] || {:action  => :index}

    # Get the upload stream object
    upload_stream = params[:upload_file]   # an object encoding the file data stream
    if upload_stream.blank?
      redirect_to redirect_path
      return
    end

    # Save raw content of the file; we don't know yet
    # whether it's an archive or not, or if we'll extract it etc.
    basename               = File.basename(upload_stream.original_filename)

    # Temp file where the data is saved by rack
    rack_tempfile_path = upload_stream.tempfile.path
    rack_tempfile_size = upload_stream.tempfile.size

    # Get the data provider for the destination files.
    data_provider_id = params[:data_provider_id]

    # Where we'll keep a copy in the spawn() below
    tmpcontentfile     = "/tmp/#{Process.pid}-#{rand(10000).to_s}-#{basename}" # basename's extension is used later on

    # Decide what to do with the raw data
    if params[:archive] == 'save'  # the simplest case first

      file_type = SingleFile unless file_type <= SingleFile
      userfile  = file_type.new(
                      params[:userfile].merge(
                     :name             => basename,
                     :user_id          => current_user.id,
                     :data_provider_id => data_provider_id,
                     :tag_ids          => params[:tags]
                   )
                 )

      if ! userfile.save
        flash[:error]  += "File '#{basename}' could not be added.\n"
        userfile.errors.each do |field, error|
          flash[:error] += "#{field.to_s.capitalize} #{error}.\n"
        end
        redirect_to redirect_path
        return
      end

      flash[:notice] += "File '#{basename}' being added in background."

      system("cp '#{rack_tempfile_path}' '#{tmpcontentfile}'") # fast, hopefully; maybe 'mv' would work?
      CBRAIN.spawn_with_active_records(current_user,"Upload of SingleFile") do
        begin
          userfile.cache_copy_from_local_file(tmpcontentfile)
          userfile.size = rack_tempfile_size
          userfile.save
          userfile.addlog_context(self,"Uploaded by #{current_user.login}")
          current_user.addlog_context(self,"Uploaded SingleFile '#{userfile.name}', #{userfile.size} bytes")
          Message.send_message(current_user,
                               :message_type  => 'notice', 
                               :header  => "SingleFile Uploaded", 
                               :variable_text  => "#{userfile.name} [[View][/userfiles/#{userfile.id}]]"
                               )
        ensure
          File.delete(tmpcontentfile) rescue true
        end
      end # spawn
      
      redirect_to redirect_path
      return
    end # save



    # We will be processing some archive file.
    # First, check for supported extensions
    if basename !~ /(\.tar|\.tgz|\.tar.gz|\.zip)$/i
      flash[:error] += "Error: file #{basename} does not have one of the supported extensions: .tar, .tar.gz, .tgz or .zip.\n"
      redirect_to redirect_path
      return
    end

    # Create a collection
    if params[:archive] =~ /collection/

      collection_name = basename.split('.')[0]  # "abc"
      if current_user.userfiles.exists?(:name => collection_name, :data_provider_id => data_provider_id)
        flash[:error] = "Collection '#{collection_name}' already exists.\n"
        redirect_to redirect_path
        return
      end

      collectionType = file_type
      collectionType = FileCollection unless file_type <= FileCollection

      collection = collectionType.new(
        params[:userfile].merge(
          :name              => collection_name,
          :user_id           => current_user.id,
          :data_provider_id  => data_provider_id,
          :tag_ids           => params[:tags]
        )
      )
      
      if collection.save

        system("cp '#{rack_tempfile_path}' '#{tmpcontentfile}'") # fast, hopefully; maybe 'mv' would work?
        CBRAIN.spawn_with_active_records(current_user,"FileCollection Extraction") do
          begin
            collection.extract_collection_from_archive_file(tmpcontentfile)
            Message.send_message(current_user,
                                  :message_type  => 'notice', 
                                  :header  => "Collection Uploaded", 
                                  :variable_text  => collection.name
                                  )
          ensure
            File.delete(tmpcontentfile) rescue true
          end
        end # spawn
      
        flash[:notice] = "Collection '#{collection_name}' created."
        current_user.addlog_context(self,"Uploaded FileCollection '#{collection_name}'")
        redirect_to redirect_path
      else
        flash[:error] = "Collection '#{collection_name}' could not be created.\n"
        collection.errors.each do |field, error|
          flash[:error] += field.to_s.capitalize + " " + error + ".\n"
        end
        redirect_to redirect_path
      end # save collection
      return
    end



    # At this point, create a bunch of userfiles from the archive
    cb_error "Unknown action #{params[:archive]}" if params[:archive] != 'extract'

    # Common attributes to all files
    attributes = params[:userfile].merge({
      :user_id           => current_user.id,
      :data_provider_id  => data_provider_id,
      :tag_ids           => params[:tags]
    })

    # Do it in background.
    system("cp '#{rack_tempfile_path}' '#{tmpcontentfile}'") # fast, hopefully; maybe 'mv' would work?
    CBRAIN.spawn_with_active_records(current_user,"Archive extraction") do
      begin
        extract_from_archive(tmpcontentfile, file_type, attributes) # generates its own Messages
      ensure
        File.delete(tmpcontentfile) rescue true
      end
    end # spawn

    flash[:notice] += "Your files are being extracted and added in background."
    redirect_to redirect_path
  end

  # PUT /userfiles/1
  # PUT /userfiles/1.xml
  def update  #:nodoc:
    @userfile = Userfile.find_accessible_by_user(params[:id], current_user, :access_requested => :write)

    flash[:notice] = ""
    flash[:error]  = ""

    attributes    = params[:userfile] || {}
    new_user_id   = attributes.delete :user_id
    new_group_id  = attributes.delete :group_id
    old_name      = new_name = @userfile.name 

    if @userfile.has_owner_access?(current_user)
      # IMPORTANT: File type change MUST come first as we will change the class of the object.
      if params[:file_type]
        if @userfile.update_file_type(params[:file_type], current_user)
          @userfile = Userfile.find(@userfile.id)
        else
          @userfile.errors.add(:type, "could not be updated.")
        end
      end
      
      old_name = @userfile.name
      new_name = attributes.delete(:name) || old_name

      @userfile.user_id  = new_user_id  if current_user.available_users.where(:id => new_user_id).first
      @userfile.group_id = new_group_id if current_user.available_groups.where(:id => new_group_id).first
      
      if @userfile.update_attributes_with_logging(attributes, current_user, %w( group_writable num_files format_source_id parent_id ) )
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
      else
        @userfile.reload
        format.html { render(:action  => 'show') }
        format.xml  { render :xml => @userfile.errors, :status => :unprocessable_entity }
      end
    end
  end
  
  # Updated tags, groups or group-writability flags for several
  # userfiles.
  def update_multiple #:nodoc:
    file_ids         = params[:file_ids]
    commit_value     = params[:commit]
    
    # First selection no need to be in spawn
    invalid_tags     = 0
    unable_to_update = nil

    operation = 
      case commit_value
        when "Update Tags"
          new_tags         = params[:tags]
          new_tags.reject! { |tag| !current_user.available_tags.where(:id => tag.to_i).exists? && invalid_tags += 1 }
          unable_to_update = "tag"     if new_tags.empty?
          ['set_tags_for_user', current_user, new_tags]
        when "Update Projects"
          new_group_id     = params[:userfile][:group_id].to_i
          unable_to_update = "project" if !current_user.available_groups.where(:id => new_group_id).exists?
          ["update_attributes_with_logging", {:group_id => new_group_id}, current_user]
        when "Update Permissions"
          ["update_attributes_with_logging", {:group_writable => params[:userfile][:group_writable]}, current_user, [ 'group_writable' ] ]
        when "Update Owner"
          new_user_id      = params[:userfile][:user_id].to_i
          unable_to_update = "owner"   if !current_user.available_users.where(:id => new_user_id).exists?
          ["update_attributes_with_logging", {:user_id => new_user_id}, current_user]
        when "Update"
          ["update_file_type", params[:file_type], current_user]
        else
          nil
      end

    if unable_to_update.present? || !operation.present?
      flash[:error]   = "You do not have access to this #{unable_to_update}." if unable_to_update.present?
      flash[:error]   = "Unknown operation for the update files."             if !operation.present?
      redirect_action = params[:redirect_action] || {:action => :index, :format => request.format.to_sym}
      redirect_to redirect_action
      return
    end

    flash[:error] = "You do not have access to all tags you want to update." unless invalid_tags == 0

    do_in_spawn      = file_ids.size > 5
    success_count    = 0
    failure_count    = 0
    CBRAIN.spawn_with_active_records_if(do_in_spawn,current_user,"Sending update to files") do
      access_requested = commit_value == "Update Tags" ? :read : :write
      filelist         = Userfile.find_all_accessible_by_user(current_user, :access_requested => access_requested ).where(:id => file_ids).all 
      failure_count   += file_ids.size - filelist.size   

      # Filter file list
      case commit_value
        # Critical! Case values must match labels of submit buttons!
        when "Update Projects"
          user_to_avail_group_ids = {}
          filelist.reject! do |file|
            f_uid = file.user_id
            # File's owner need to have access to new group
            user_to_avail_group_ids[f_uid] ||= User.find(f_uid).available_groups.map(&:id).index_by { |id| id }
            (! user_to_avail_group_ids[f_uid][new_group_id]) && failure_count += 1
          end
        when "Update Owner"
          new_filelist = filelist.select(&:allow_file_owner_change?)
          failure_count += (filelist.size - new_filelist.size)
          filelist = new_filelist
      end

      # Update the attribute for each file
      filelist.each do |userfile|
        if userfile.send(*operation)
          success_count += 1
        else
          failure_count +=1
        end
      end
      
      # Async Notification
      if do_in_spawn
       variable_text  = success_count > 0 ? "#{commit_value.humanize} successful for #{view_pluralize(success_count, "file")}.\n" : ""
       variable_text += "#{commit_value.humanize} unsuccessful for #{view_pluralize(failure_count, "file")}." if failure_count > 0
       Message.send_message(current_user, {
          :header        => "Finished sending update to your files.\n",
          :message_type  => :notice,
          :variable_text => variable_text
          }
        )
      end
      
    end # spawn end

    # Sync notification
    if do_in_spawn
      flash[:notice] = "The file are being updated in background."
    else
      flash[:notice] = "#{commit_value.humanize} successful for #{view_pluralize(success_count, "file")}."   if success_count > 0
      flash[:error]  = "#{commit_value.humanize} unsuccessful for #{view_pluralize(failure_count, "file")}." if failure_count > 0
    end
    
    redirect_action  = params[:redirect_action] || {:action => :index, :format => request.format.to_sym}
    redirect_to redirect_action
  end

  def quality_control #:nodoc:
    @filelist = params[:file_ids] || []
  end
  
  def quality_control_panel #:nodoc:
    @filelist      = params[:file_ids] || []
    @current_index = params[:index]    || -1    
    
    @current_index = @current_index.to_i
    
    admin_user     = User.find_by_login("admin")
    everyone_group = Group.everyone
    
    pass_tag    = current_user.available_tags.find_or_create_by_name_and_user_id_and_group_id("QC_PASS", admin_user.id, everyone_group.id)
    fail_tag    = current_user.available_tags.find_or_create_by_name_and_user_id_and_group_id("QC_FAIL", admin_user.id, everyone_group.id)
    unknown_tag = current_user.available_tags.find_or_create_by_name_and_user_id_and_group_id("QC_UNKNOWN", admin_user.id, everyone_group.id)
    
    if @current_index >=  0 && params[:commit] && params[:commit] != "Next" && params[:commit] != "Previous"
      @current_userfile = Userfile.find_accessible_by_user(@filelist[@current_index], current_user, :access_requested => :read)
      tag_ids = params[:tag_ids] || []
      case params[:commit]
      when "Pass"
        tag_ids |= [pass_tag.id.to_s]
      when "Fail"
        tag_ids |= [fail_tag.id.to_s]
      when "Unknown"
        tag_ids |= [unknown_tag.id.to_s]
      end
      @current_userfile.set_tags_for_user(current_user, tag_ids)
    end
    
    if params[:commit] == "Previous" && @current_index > 0
      @current_index -= 1
    elsif @current_index < @filelist.size-1
      @current_index += 1
    end
    
    @userfile = Userfile.find_accessible_by_user(@filelist[@current_index], current_user, :access_requested => :read)
    partial_base = "userfiles/quality_control/"
    if File.exists?(Rails.root.to_s + "/app/views/#{partial_base}_#{@userfile.class.name.underscore}.#{request.format.to_sym}.erb")
      @partial = partial_base + @userfile.class.name.underscore
    else
      @partial = partial_base + "default"
    end
    
    render :partial => "quality_control_panel"
  end
  
  #Create a collection from the selected files.
  def create_collection #:nodoc:
    filelist    = params[:file_ids] || []
    if current_project
      file_group = current_project.id
    else
      file_group = current_user.own_group.id
    end
    
    collection = FileCollection.new(
        :user_id          => current_user.id,
        :group_id         => file_group,
        :data_provider    => DataProvider.find(params[:data_provider_id])
        )

    CBRAIN.spawn_with_active_records(current_user,"Collection Merge") do
      result = collection.merge_collections(Userfile.find_accessible_by_user(filelist, current_user, :access_requested  => :read))
      if result == :success
        Message.send_message(current_user,
                            :message_type  => 'notice', 
                            :header  => "Collections Merged", 
                            :variable_text  => "[[#{collection.name}][/userfiles/#{collection.id}]]"
                            )
      else
        Message.send_message(current_user,
                            :message_type  => 'error', 
                            :header  => "Collection could not be merged.", 
                            :variable_text  => "There was a collision among the file names."
                            )
      end
    end # spawn

    flash[:notice] = "Collection #{collection.name} is being created in background."
    redirect_to :action => :index, :format => request.format.to_sym
    
  end
  
  # Copy or move files to a new provider.
  def change_provider #:nodoc:

    # Operaton to perform
    if params[:commit] =~ /move/i
      task      = 'move'
    elsif params[:commit] =~ /copy/i
      task      = 'copy'
    end

    # Option for move or copy.
    crush_destination = (params[:crush_destination].to_s =~ /crush/i) ? true : false
    
    # File list to apply operation
    filelist    = params[:file_ids] || []

    # Default message keywords for 'move'
    word_move  = 'move'
    word_moved = 'moved'
    if task == 'copy'  # switches to 'copy' mode, so adjust the words
      word_move  = 'copy'
      word_moved = 'copied'
    end

    # Destination provider
    data_provider_id = params[:data_provider_id]
    new_provider = DataProvider.find_all_accessible_by_user(current_user).where( :id => data_provider_id, :online => true, :read_only => false ).first
    unless new_provider
      flash[:error] = "Data provider #{data_provider_id} not accessible.\n"
      redirect_to :action => :index, :format => request.format.to_sym
      return
    end

    # Spawn subprocess to perform the move operations
    CBRAIN.spawn_with_active_records(current_user,"#{word_move.capitalize} To Other Data Provider") do
      moved_list  = []
      failed_list = {}
      filelist.each do |id|
        begin
          u = Userfile.find_accessible_by_user(id, current_user, :access_requested => (task == 'copy' ? :read : :write) )
          next unless u
          orig_provider = u.data_provider
          next if orig_provider.id == data_provider_id # not support for copy to same provider in the interface, yet.
          res = nil
          if task == 'move'
            raise "Not owner." unless u.has_owner_access?(current_user)
            res = u.provider_move_to_otherprovider(new_provider, :crush_destination => crush_destination)
          else
            my_group_id  = current_project ? current_project.id : current_user.own_group.id
            res = u.provider_copy_to_otherprovider(new_provider,
                     :user_id           => current_user.id,
                     :group_id          => my_group_id,
                     :crush_destination => crush_destination
                  )
          end
          raise "File collision: there is already such a file on the other provider." unless res
          u.cache_erase rescue nil 
          moved_list << u
        rescue => e
          if u.is_a?(Userfile)
            err_message = e.message
            failed_list[err_message] ||= []
            failed_list[err_message] << u
          else
            raise e
          end
        end
      end

      if moved_list.size > 0
        Message.send_message(current_user,
                            :message_type  => 'notice', 
                            :header  => "Files #{word_moved} to #{new_provider.name}",
                            :variable_text  => "List:\n" + moved_list.map { |u| "[[#{u.name}][/userfiles/#{u.id}]]\n" }.join("")
                            ) 
      end

      if failed_list.size > 0
        report = ""
        failed_list.each do |message,userfiles|
          report += "Failed because: #{message}\n"
          report += userfiles.map { |u| "[[#{u.name}][/userfiles/#{u.id}]]\n" }.join("")
        end
        Message.send_message(current_user,
                            :message_type  => 'error', 
                            :header        => "Some files could not be #{word_moved} to #{new_provider.name}",
                            :variable_text => report
                            )
      end

    end # spawn

    flash[:notice] = "Your files are being #{word_moved} in the background.\n"
    redirect_to :action => :index, :format => request.format.to_sym
  end

  # Adds the selected userfile IDs to the session's persistent list
  def manage_persistent #:nodoc:
    filelist    = params[:file_ids] || []

    if (params[:operation] || 'clear') =~ /(clear|add|remove|replace)/i
      operation = Regexp.last_match[1].downcase
    else
      operation = 'clear'
    end

    flash[:notice] = ""

    cleared_count = added_count = removed_count = 0

    if operation == 'clear' || operation == 'replace'
      cleared_count = current_session.persistent_userfile_ids_clear
      flash[:notice] += "#{view_pluralize(cleared_count, "file")} cleared from persistent list.\n" if cleared_count > 0
    end

    if operation == 'add'   || operation == 'replace'
      added_count   = current_session.persistent_userfile_ids_add(filelist)
      flash[:notice] += "#{view_pluralize(added_count, "file")} added to persistent list.\n" if added_count > 0
    end

    if operation == 'remove'
      removed_count = current_session.persistent_userfile_ids_remove(filelist)
      flash[:notice] += "#{view_pluralize(removed_count, "file")} removed from persistent list.\n" if removed_count > 0
    end

    persistent_ids = current_session.persistent_userfile_ids_list
    flash[:notice] += "Total of #{view_pluralize(persistent_ids.size, "file")} now in the persistent list of files.\n" if
      persistent_ids.size > 0 && (added_count > 0 || removed_count > 0 || cleared_count > 0)

    flash[:notice] += "No changes made to the persistent list of userfiles." if
      added_count == 0 && removed_count == 0 && cleared_count == 0

    redirect_to :action => :index, :page => params[:page]
  end
  
  #Delete the selected files.
  def delete_files #:nodoc:
    filelist    = params[:file_ids] || []

    # Delete in background
    CBRAIN.spawn_with_active_records(current_user, "Delete files.") do
      first_error        = nil
      deleted_count      = 0
      unregistered_count = 0
      error_count        = 0
      
      Userfile.find_accessible_by_user(filelist, current_user, :access_requested => :write).each do |userfile|
        begin
          basename = userfile.name
          if userfile.data_provider.is_browsable? && userfile.data_provider.meta[:must_erase].blank?
            unregistered_count += 1
          else
            deleted_count += 1
          end
          userfile.destroy
        rescue => e
          error_count += 1
          first_error ||= "for '#{userfile.name}': #{e.message}.\n"
        end
      end

      variable_text  = ""
      error_messages = ""
      if deleted_count > 0
        variable_text += "#{view_pluralize(deleted_count, "file")} deleted.\n"
      end
      if unregistered_count > 0
        variable_text += "#{view_pluralize(unregistered_count, "file")} unregistered.\n"
      end
      if error_count > 0
        error_messages += "#{view_pluralize(error_count, "internal error")} when deleting/unregistering file(s).\n"
        error_messages += "The first error was #{first_error}.\n"
      end

      variable_text = "No file has been deleted or unregistered.\n" if variable_text.blank?
      
      Message.send_message(current_user,
                     :message_type => 'notice',
                     :header       => "Finished deleting/unregistering files." + (error_messages.blank? ? "" : " (with some errors)"),
                     :variable_text => "#{variable_text}#{error_messages}" 
                    )
    end # spawn

    flash[:notice] = "Your files are being deleted in background."
    redirect_to :action => :index, :format => request.format.to_sym
  end
  

  # Dowload the selected files.
  def download #:nodoc:
    filelist           = params[:file_ids] || []
    specified_filename = params[:specified_filename]
    
    # Check or build filename for downloaded data
    # Does NOT include .tar.gz extensions, which will be added later if necessary
    if ! specified_filename.blank?
      specified_filename.sub!(/(\.tar)?(\.g?z)?$/i,"")
      if ! Userfile.is_legal_filename?(specified_filename)
          flash[:error] = "Error: filename '#{specified_filename}' is not acceptable (illegal characters?)."
          redirect_to :action => :index, :format =>  request.format.to_sym
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
      redirect_to :action => :index, :format =>  request.format.to_sym
      return
    end

    # Sync all files
    userfiles_list.each { |u| u.sync_to_cache rescue true }

    # When sending a single file, just throw it at the browser.
    if filelist.size == 1 && userfiles_list[0].is_a?(SingleFile)
      userfile = userfiles_list[0]
      fullpath = userfile.cache_full_path
      send_file fullpath, :stream => true, :filename => is_blank ? fullpath.basename : specified_filename        
      return
    end

    # When several files are to be sent, create and send a .tar.gz file
    tarfile = create_relocatable_tar_for_userfiles(userfiles_list,current_user.login)
    send_file tarfile, :stream  => true, :filename => "#{specified_filename}.tar.gz"
    CBRAIN.spawn_fully_independent("DL clean #{current_user.login}") do
      sleep 300
      File.unlink(tarfile)
    end
  end

  #Extract a file from a collection and register it separately
  #in the database.
  def extract_from_collection #:nodoc:
    success = failure = 0

    unless params[:file_names] && params[:file_names].size > 0
      flash[:notice] = "No files selected for extraction"
      redirect_to :action  => :edit
      return
    end

    collection = FileCollection.find_accessible_by_user(params[:id], current_user, :access_requested  => :read)
    collection_path = collection.cache_full_path
    data_provider_id = collection.data_provider_id
    params[:file_names].each do |file|
      userfile = SingleFile.new(
          :name             => File.basename(file),
          :user_id          => current_user.id,
          :group_id         => collection.group_id,
          :data_provider_id => data_provider_id
      )
      Dir.chdir(collection_path.parent) do
        if userfile.save
          userfile.addlog("Extracted from collection '#{collection.name}'.")
          userfile.cache_copy_from_local_file(file)
          success += 1
        else
          failure += 1
        end
      end
      if success > 0
        flash[:notice] = "#{success} files were successfuly extracted."
      end
      if failure > 0
        flash[:error] =  "#{failure} files could not be extracted."
      end
    end

    redirect_to :action  => :index
  end

  # Compress or uncompress a set of userfiles; only supported
  # for SingleFiles.
  def compress  #:nodoc:
    filelist    = params[:file_ids] || []
    
    to_compress        = []
    to_uncompress      = []
    skipped_messages   = {}

    Userfile.find_accessible_by_user(filelist, current_user, :access_requested => :write).each do |userfile|

      unless userfile.is_a?(SingleFile)
        (skipped_messages["Not a SingleFile"] ||= []) << userfile
        next
      end
      if userfile.data_provider.read_only?
        (skipped_messages["Data Provider not writable"] ||= []) << userfile
        next
      end

      basename = userfile.name

      if basename =~ /\.gz$/i
        destbase = basename.sub(/\.gz$/i,"")
      else
        destbase = basename + ".gz"
      end

      if Userfile.where(
           :name             => destbase,
           :user_id          => userfile.user_id,
           :data_provider_id => userfile.data_provider_id
         ).first
        (skipped_messages["Filename collision"] ||= []) << userfile
        next
      end

      if basename =~ /\.gz$/i
        to_uncompress << [ userfile, :uncompress, destbase ]
      else
        to_compress   << [ userfile, :compress,   destbase ]
      end

    end

    if to_compress.size > 0 || to_uncompress.size > 0
      CBRAIN.spawn_with_active_records(current_user, "Compression") do
        error_messages = ""
        done_ok = []
        (to_compress + to_uncompress).each do |u_triplet|
          userfile,do_what,destbase = *u_triplet
          begin
            if ! userfile.provider_rename(destbase)
              error_messages += "Could not do basic renaming to #{destbase}'.\n"
              next
            end
            userfile.sync_to_cache
            SyncStatus.ready_to_modify_cache(userfile) do
              full_after = userfile.cache_full_path.to_s
              full_tmp   = "#{full_after}+#{$$}+#{Time.now.to_i}"
              command = (do_what == :compress) ? "gzip" : "gunzip"
              system("#{command} -c < '#{full_after}' > '#{full_tmp}'")
              File.rename(full_tmp,full_after) # crush it
            end
            userfile.sync_to_provider
            done_ok << userfile
          rescue => e
            error_messages += "Internal error (un)compresssing for '#{userfile.name}': #{e.message}.\n"
          end
        end
        Message.send_message(current_user,
                             :message_type => 'notice',
                             :header       => "Finished compressing or uncompressing files." + (error_messages.blank? ? "" : " (with some errors)"),
                             :variable_text => done_ok.map { |u| "[[#{u.name}][/userfiles/#{u.id}]]" }.join(", ") + "\n" + error_messages
                            )
      end # spawn
    end # if anything to do
  
    info_message = ""
    if to_compress.size > 0
      info_message += "#{view_pluralize(to_compress.size, "file")} being compressed in background.\n"
    end
    if to_uncompress.size > 0
      info_message += "#{view_pluralize(to_uncompress.size, "file")} being uncompressed in background.\n"
    end
    skipped_messages.each do |mess,userfiles|
      info_message += "Warning: some files were skipped; Reason: #{mess}; Files: "
      info_message += userfiles.map { |u| "#{u.name}" }.join(", ") + "\n"
    end

    flash[:notice] = info_message unless info_message.blank?
    
    redirect_to :action => :index, :format => request.format.to_sym
  end

  private

  # Adds the persistent userfile ids to the params[:file_ids] argument
  def auto_add_persistent_userfile_ids #:nodoc:
    params[:file_ids] = (params[:file_ids] || []) | current_session.persistent_userfile_ids_list
  end

  # Verify that all files selected for an operation
  # are accessible by the current user.
  def permission_check #:nodoc:
    action_name = params[:action].to_s
    if params[:file_ids].blank? && action_name != 'manage_persistent'
      flash[:error] = "No files selected? Selection cleared.\n"
      redirect_to :action => :index, :format => request.format.to_sym
      return
    end
    if action_name == "update_multiple"
      action_name = params[:commit].to_s + " on"
    end
    
    yield
  rescue ActiveRecord::RecordNotFound => e
    flash[:error] += "\n" unless flash[:error].blank?
    flash[:error] ||= ""
    flash[:error] += "You don't have appropriate permissions to apply the selected action to this set of files."

    redirect_to :action => :index, :format => request.format.to_sym
  end
  
  #Extract files from an archive and register them in the database.
  #+archive_file_name+ is a path to an archive file (tar or zip).
  #+attributes+ is a hash of attributes for all the files,
  #they must contain at least user_id and data_provider_id
  def extract_from_archive(archive_file_name, file_type = SingleFile, attributes = {}) #:nodoc:

    file_type = SingleFile unless file_type <= SingleFile
    escaped_archivefile = archive_file_name.gsub("'", "'\\\\''") # bash escaping

    # Check for required attributes
    data_provider_id    = attributes["data_provider_id"] ||
                          attributes[:data_provider_id]
    cb_error "No data provider ID supplied." unless data_provider_id

    user_id             = attributes["user_id"]  ||
                          attributes[:user_id]
    cb_error "No user ID supplied." unless user_id

    # Create content list
    all_files        = []
    if archive_file_name =~ /(\.tar.gz|\.tgz)$/i
      all_files = IO.popen("tar -tzf '#{escaped_archivefile}'") { |fh| fh.readlines.map(&:chomp) }
    elsif archive_file_name =~ /\.tar$/i
      all_files = IO.popen("tar -tf '#{escaped_archivefile}'") { |fh| fh.readlines.map(&:chomp) }
    elsif archive_file_name =~ /\.zip/i
      all_files = IO.popen("unzip -l '#{escaped_archivefile}'") { |fh| fh.readlines.map(&:chomp)[3..-3].map{ |line|  line.split[3]} }
    else
      cb_error "Cannot process file with unknown extension: #{archive_file_name}"
    end

    count = all_files.select{ |f| f !~ /\// }.size

    #max of 50 files can be added to the file list at a time.
    cb_error "Overflow: more than 50 files found in archive." if count > 50

    workdir = "/tmp/filecollection.#{Process.pid}"
    Dir.mkdir(workdir)
    Dir.chdir(workdir) do
      if archive_file_name =~ /(\.tar.gz|\.tgz)$/i
        system("tar -xzf '#{escaped_archivefile}'")
      elsif archive_file_name =~ /\.tar$/i
        system("tar -xf '#{escaped_archivefile}'")
      elsif archive_file_name =~ /\.zip/i
        system("unzip '#{escaped_archivefile}'")
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
        u = file_type.new(attributes)
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
        :description  => "Some errors occured while extracting files from archive '#{archive_file_name}'",
        :variable_text  => report
      )
    end
                         
  end

  # This method creates a tar file of the userfiles listed
  # in +ulist+ (an array of Userfiles) such that
  # the tar structure is independent of the DP path
  # and owners. Each userfile basename 'x' will be
  # stored as a relative path 'user/dpname/x'. This
  # is needed when downloading a file, as a user is
  # allowed to have several files with the same names
  # on different DPs, and several users are allowed to
  # have files with the same names on the same DP.
  def create_relocatable_tar_for_userfiles(ulist,username) #:nodoc:
    timestamp    = Time.now.to_i.to_s[-4..-1]  # four digits long
    tmpdir       = Pathname.new("/tmp/dl.#{Process.pid}.#{timestamp}")
    tarfilename  = Pathname.new("/tmp/cbrain_files_#{username}.#{timestamp}.tar.gz") # must be outside the tmp work dir
    
    relpath_to_tar = []
    Dir.mkdir(tmpdir)
    Dir.chdir(tmpdir) do  # /tmpdir

      uids = ulist.group_by { |u1| u1.user_id }
      uids.each do |uid,userfiles_per_user|
        uname = User.find(uid).login
        Dir.mkdir(uname)
        Dir.chdir(uname) do # /tmpdir/user/dp

          dpids = userfiles_per_user.group_by { |u2| u2.data_provider_id }
          dpids.each do |dpid,userfiles_per_dp|
            dpname = DataProvider.find(dpid).name
            Dir.mkdir(dpname)
            Dir.chdir(dpname) do # /tmpdir/user/dp

              userfiles_per_dp.each do |u|
                fullpath = u.cache_full_path
                basename = fullpath.basename
                File.symlink(fullpath,basename) # /tmpdir/user/dp/basename -> fullpath
                relpath_to_tar << Pathname.new(uname) + dpname + basename
              end # each file per dp per user
            end # chdir tmpdir/user/dp
          end # each dp per user
        end # chdir tmpdir/user
      end # each user

      filelistname = "files_for_#{username}.#{Process.pid}.lst"
      File.open(filelistname,"w") do |fh|
        fh.write relpath_to_tar.join("\n")
        fh.write "\n"
      end

      system("tar -chf - -T #{filelistname} | gzip -c >#{tarfilename}")

    end # chdir tmpdir

    return tarfilename
  ensure
    FileUtils.remove_entry(tmpdir, true)
    return tarfilename
  end

  private

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

end
