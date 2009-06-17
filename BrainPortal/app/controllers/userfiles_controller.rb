
#
# CBRAIN Project
#
# RESTful Userfiles Controller
#
# Original author: Tarek Sherif
#
# $Id$
#

class UserfilesController < ApplicationController

  Revision_info="$Id$"
  
  before_filter :login_required
  
  # GET /userfiles
  # GET /userfiles.xml
  def index    
    current_session.update(params)
        
    tag_filters, name_filters  = current_session.current_filters.partition{|filter| filter.split(':')[0] == 'tag'}
        
    unless current_session.view_all? 
      @userfiles = current_user.userfiles.find(:all, :include  => :tags, 
        :conditions => Userfile.convert_filters_to_sql_query(name_filters),
        :order => "userfiles.#{current_session.order}")
    else
      @userfiles = Userfile.find(:all, :include  => :tags, 
        :conditions => Userfile.convert_filters_to_sql_query(name_filters),
        :order => "userfiles.#{current_session.order}")
    end

    @userfile_count = @userfiles.size
    
    #@userfiles = @userfiles.group_by(&:user_id).inject([]){|f,u| f + u[1].sort}
    @userfiles = Userfile.apply_tag_filters(@userfiles, tag_filters)
    
    if current_session.paginate?
      @userfiles = Userfile.paginate(@userfiles, params[:page] || 1, current_user.user_preference.other_options["userfiles_per_page"])
    end

    @search_term = params[:search_term] if params[:search_type] == 'name_search'
    @user_tags = current_user.tags.find(:all)
    @user_groups = current_user.groups.find(:all)
    
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @userfiles }
    end
  end

  # GET /userfiles/1
  # GET /userfiles/1.xml
  def show
    unless current_user.has_role? :admin
      @userfile = current_user.userfiles.find(params[:id])
    else
      @userfile = Userfile.find(params[:id])
    end
    
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @userfile }
    end
  end
  
  # Returns the content of a file; used mostly by JIV
  # GET /userfiles/1/content
  def content
    userfile = current_user.userfiles.find(params[:id])
    userfile.sync_to_cache
    send_file userfile.cache_full_path
  end

  # GET /userfiles/new
  # GET /userfiles/new.xml
  def new
    @user_groups = current_user.groups.find(:all)
    @user_tags = current_user.tags.find(:all)
    @data_providers = DataProvider.find(:all, :conditions => { :online => true, :read_only => false }).select { |p| p.can_be_accessed_by(current_user) }
    
    upload_stream = params[:upload_file]   # an object encoding the file data stream
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @userfile }
    end
  end

  # GET /userfiles/1/edit
  def edit
    session[:full_civet_display] ||= 'on'
    
    if params[:full_civet_display]
      session[:full_civet_display] = params[:full_civet_display]
    end
    
    if current_user.has_role? :admin
      @userfile = Userfile.find(params[:id])
    else
      @userfile = current_user.userfiles.find(params[:id])      
    end
    
    @tags = current_user.tags.find(:all)
  end

  # POST /userfiles
  # POST /userfiles.xml
  def create
  
     upload_stream = params[:upload_file]   # an object encoding the file data stream
    if upload_stream.blank?
      redirect_to :action => :index
      return
    end
    
    userfile = nil
    data_provider_id = params[:data_provider_id]
    if data_provider_id.empty?
      data_provider_id = DataProvider.find_first_online_rw(current_user).id
    end

    if params[:archive] == 'collection'
      userfile         = FileCollection.new(:tag_ids  => params[:tags])
    elsif params[:archive] == 'civet collection'
      userfile         = CivetCollection.new(:tag_ids  => params[:tags])
      params[:archive] = 'collection'
    else
      userfile         = SingleFile.new(:tag_ids  => params[:tags])
    end

    clean_basename   = File.basename(upload_stream.original_filename)
    userfile.name    = clean_basename
    userfile.user_id = current_user.id
    userfile.data_provider_id = data_provider_id
    userfile.group_id = params[:userfile][:group_id] if params[:userfile] && params[:userfile][:group]
    userfile.content = upload_stream.read   # also fills file_size

    if params[:archive] == 'extract' && userfile.name =~ /(\.tar(\.gz)?|\.zip)$/
      status, successful_files, failed_files, nested_files = userfile.extract
      if status == :success
        if successful_files.size > 0
          flash[:notice] = "#{successful_files.size} files successfully added."          
        end
        if failed_files.size > 0
          flash[:error]  = "#{failed_files.size} files could not be added.\n"          
        end
        if nested_files.size > 0
          flash[:error] ||= ""
          flash[:error]  += "#{nested_files.size} files could not be added as they are nested in directories."          
        end
      elsif status == :overflow
        flash[:error] = "Maximum of 50 files can be auto-extracted at a time.\nCreate a collection if you wish to add more."
      else
        flash[:error]  = "Some or all of the files were not extracted properly (internal error?).\n"
      end
    elsif params[:archive] == 'collection' && userfile.name =~ /(\.tar(\.gz)?|\.zip)$/
      collection_name = userfile.name.split('.')[0]
      if current_user.userfiles.exists?(:name => collection_name)
        flash[:error] = "File '" + collection_name + "' already exists."
        redirect_to :action => :index
        return
      end
        
      if userfile.extract_collection  
        flash[:notice] = "Collection '#{userfile.name}' created."
      else
        flash[:error] = "Collection '#{userfile.name}' could not be created."
      end
    else
      if current_user.userfiles.exists?(:name => userfile.name, :data_provider_id => data_provider_id)
          flash[:error] = "File '" + userfile.name + "' already exists."
          redirect_to :action => :index
          return
      end
      if userfile.save
        flash[:notice] = "File '" + clean_basename + "' added."
      else
        flash[:error]  = "File '" + clean_basename + "' could not be added (internal error?)."
      end
    end
    redirect_to :action => :new
  end

  # PUT /userfiles/1
  # PUT /userfiles/1.xml
  def update
    if current_user.has_role? :admin
      @userfile = Userfile.find(params[:id])
    else
      @userfile = current_user.userfiles.find(params[:id])      
    end

    flash[:notice] ||= ""
    flash[:error] ||= ""
    
    attributes = (params[:single_file] || params[:file_collection] || params[:civet_collection] || {}).merge(params[:userfile] || {})    
    attributes['tag_ids'] ||= []
    
    old_name = @userfile.name
    new_name = attributes[:name] || old_name
    if ! Userfile.is_legal_filename?(new_name)
      flash[:error] += "Error: filename '#{new_name}' is not acceptable (illegal characters?)."
      new_name = old_name
    end

    attributes[:name] = old_name # we must NOT rename the file yet
    
    respond_to do |format|
      if @userfile.update_attributes(attributes)
        flash[:notice] += "#{@userfile.name} successfully updated."
        if new_name != old_name
           @userfile.provider_rename(new_name) # this also modifies and saves @userfile
        end
        format.html { redirect_to(userfiles_url) }
        format.xml  { head :ok }
      else
        flash[:error] += "#{@userfile.name} has NOT been updated."
        @userfile.name = old_name
        @tags = current_user.tags
        @groups = current_user.groups
        format.html { render :action  => 'edit' }
        format.xml  { render :xml => @userfile.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /userfiles/1
  # DELETE /userfiles/1.xml
  def destroy
    @userfile = Userfile.find(params[:id])
    @userfile.destroy

    respond_to do |format|
      format.html { redirect_to(userfiles_url) }
      format.xml  { head :ok }
    end
  end
  
  def operation
    
    if params[:commit] == 'Download Files'
      operation = 'download'
    elsif params[:commit] == 'Delete Files'
      operation = 'delete_files'
    elsif params[:commit] == 'Update Tags'
      operation = 'tag_update'
    elsif params[:commit] == 'Merge Files into Collection'
      operation = 'merge_collections'
    elsif params[:commit] == 'Update Groups'
      operation = 'group_update'
    else
      operation   = 'cluster_task'
      task = params[:operation]
    end
    
    filelist    = params[:filelist] || []
    collection = current_user.has_role?(:admin) ? Userfile : current_user.userfiles

    flash[:error]  ||= ""
    flash[:notice] ||= ""

    if operation.nil? || operation.empty?
      flash[:error] += "No operation selected? Selection cleared.\n"
      redirect_to :action => :index
      return
    end

    if filelist.empty?
      flash[:error] += "No file selected? Selection cleared.\n"
      redirect_to :action => :index
      return
    end

    # TODO: replace "case" and make each operation a private method ?
    case operation
      when "cluster_task"
        redirect_to :controller => :tasks, :action => :new, :file_ids => filelist, :task => task
        return

      when "delete_files"
        
        filelist.each do |id|
          userfile = collection.find(id)
          if userfile.nil?
            flash[:error] += "File #{id} doesn't exist or is not yours.\n"
            next
          end
          basename = userfile.name
          userfile.destroy
          flash[:notice] += "File #{basename} deleted.\n"
        end

      when "download"
        if filelist.size == 1 && collection.find(filelist[0]).is_a?(SingleFile)
          userfile = collection.find(filelist[0])
          userfile.sync_to_cache
          send_file userfile.cache_full_path
        else
          cacherootdir    = DataProvider.cache_rootdir  # /a/b/c
          #cacherootdirlen = cacherootdir.to_s.size
          filenames = filelist.collect do |id| 
            u = collection.find(id)
            u.sync_to_cache
            full = u.cache_full_path.to_s        # /a/b/c/prov/x/y/basename
            #full = full[cacherootdirlen+1,9999]  # prov/x/y/basename
            full = "'" + full.gsub("'", "'\\\\''") + "'"
          end
          filenames_with_spaces = filenames.join(" ")
          tarfile = "/tmp/#{current_user.login}_files.tar.gz"
          Dir.chdir(cacherootdir) do
            system("tar -czf #{tarfile} #{filenames_with_spaces}")
          end
          send_file tarfile, :stream  => false
          File.delete tarfile
        end
        return

      when 'tag_update'
        filelist.each do |id|
          userfile = collection.find(id)
          if userfile.nil?
            flash[:error] += "File #{id} doesn't exist or is not yours.\n"
            next
          end
          if userfile.update_attributes(:tag_ids => params[:tags])
            flash[:notice] += "Tags for #{userfile.name} successfully updated."
          else
            flash[:error] += "Tags for #{userfile.name} could not be updated."
          end
        end

    when "group_update"
      filelist.each do |id|
          userfile = collection.find(id)
          if userfile.nil?
            flash[:error] += "File #{id} doesn't exist or is not yours.\n"
            next
          end
          if userfile.update_attributes(:group_id => params[:userfile][:group_id])
            flash[:notice] += "Group for #{userfile.name} successfully updated."
          else
            flash[:error] += "Group for #{userfile.name} could not be updated."
          end
    end

      when 'merge_collections'
        collection = FileCollection.new(:user_id  => current_user.id, :data_provider_id => (params[:data_provider_id] || DataProvider.find_first_online_rw(current_user).id) )
        status = collection.merge_collections(filelist)
        if status == :success
          flash[:notice] = "Collection #{collection.name} was created."
        elsif status == :collision
          flash[:error] = "There was a collision in file names. Collection merge aborted."
        else
          flash[:error] = "Collection merge fails (internal error?)."
        end 
      else
        flash[:error] = "Unknown operation #{operation}"
    end

    redirect_to :action => :index
  end
  
  def extract
    success = failure = 0
    collection_id = params[:collection_id]
    collection = FileCollection.find(collection_id)
    collection_path = collection.cache_full_path
    provider_id = collection.data_provider_id
    params[:filelist].each do |file|
      userfile = SingleFile.new(:name  => File.basename(file), :user_id => current_user.id, :data_provider_id => provider_id)
      Dir.chdir(collection_path.parent) do
        userfile.content = File.read(file)
        if userfile.save
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

end
