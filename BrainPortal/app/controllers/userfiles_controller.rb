
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
    session[:current_filters] ||= []
    
    @filter = Userfile.get_filter_name(params[:search_type], params[:search_term])   
    session[:current_filters] = [] if params[:search_type] == 'none'
    session[:current_filters] << @filter unless @filter.blank? || session[:current_filters].include?(@filter)
    session[:current_filters].delete params[:remove_filter] if params[:remove_filter]
    
    if params[:toggle_view_all] && current_user.has_role?(:admin)
      session[:view_all] = !session[:view_all]
    end
    
    unless session[:view_all] && current_user.has_role?(:admin)
      @userfiles = current_user.userfiles.find(:all, :include  => :tags)
    else
      @userfiles = Userfile.find(:all, :include  => :tags)
    end
    
    
    @userfiles = Userfile.apply_filters(@userfiles, session[:current_filters])
    unless params[:one_page]
      @userfiles = Userfile.paginate(@userfiles, params[:page] || 1)
    end
    @search_term = params[:search_term] if params[:search_type] == 'name_search'
    @user_tags = current_user.tags.find(:all)
    
    
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
  
  
  def content
    send_file current_user.userfiles.find(params[:id]).vaultname
  end

  # GET /userfiles/new
  # GET /userfiles/new.xml
  def new
    @userfile = Userfile.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @userfile }
    end
  end

  # GET /userfiles/1/edit
  def edit
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

    if params[:archive] == 'collection'
      userfile         = FileCollection.new(:tag_ids  => params[:tags])
    else
      userfile         = SingleFile.new(:tag_ids  => params[:tags])
    end
    
    clean_basename   = File.basename(upload_stream.original_filename)
    userfile.content = upload_stream.read   # also fills file_size
    userfile.user_id = current_user.id
    userfile.name    = clean_basename
    
    if params[:archive] == 'extract' && userfile.name =~ /(\.tar(\.gz)?|\.zip)$/
      success, successful_files, failed_files, nested_files = userfile.extract
      if success
        flash[:notice] = successful_files.map{|f| "File #{f} added."}.join("\n")
        flash[:error]  = failed_files.map{|f| "File '" + f + "' already exists.\n"}.join
        flash[:error]  += nested_files.map{|f| "File #{f} could not be added as it is #{f =~ /\/$/ ? '' : 'in'} a directory."}.join("\n")
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
      if current_user.userfiles.exists?(:name => userfile.name)
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
    redirect_to :action => :index
  end

  # PUT /userfiles/1
  # PUT /userfiles/1.xml
  def update
    if current_user.has_role? :admin
      @userfile = Userfile.find(params[:id])
    else
      @userfile = current_user.userfiles.find(params[:id])      
    end
    
    respond_to do |format|
      if @userfile.update_attributes(params[:userfile])
        flash[:notice] = "Tags for #{@userfile.name} successfully updated."
        format.html { redirect_to(userfiles_url) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
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
    operation   = params[:operation]
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

      when "minc2jiv"

        filelist.each do |id|
          userfile = collection.find(id)
          if userfile.nil?
            flash[:error] += "File #{id} doesn't exist or is not yours.\n"
            next
          end
          mj = DrmaaMinc2jiv.new
          mj.user_id = current_user.id
          mj.params = { :mincfile_id => id }
          mj.save
          flash[:notice] += "Started Minc2Jiv on file '#{userfile.name}'.\n"
        end
        redirect_to :controller => :tasks, :action => :index
        return

      when "civet"

        # TODO we need a new method to invoke the params page,
        # as this way (POST /civet/edit/id) can only work with
        # a single file.
        redirect_to :controller => :civet, :action => :edit, :id => filelist[0]
        return

      when "dcm2mnc"

        dm = DrmaaDcm2mnc.new
        dm.user_id = current_user.id
        dm.params = { :dicom_ids => filelist.join(",") }
        dm.save
        flash[:notice] += "Started Dcm2Mnc on your files.\n"
        redirect_to :controller => :tasks, :action => :index
        return

      when "delete"

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
          send_file collection.find(filelist[0]).vaultname
        else
          filenames = filelist.collect do |id| 
            f = collection.find(id)
            Pathname.new(f.user.login) + f.name
          end.join(" ")
          Dir.chdir(CBRAIN::Filevault_dir)
          `tar czf #{current_user.login}_files.tar.gz #{filenames}`
          Dir.chdir(RAILS_ROOT)
          send_file "#{Pathname.new(CBRAIN::Filevault_dir) + current_user.login}_files.tar.gz", :stream  => false
          File.delete "#{Pathname.new(CBRAIN::Filevault_dir) + current_user.login}_files.tar.gz"
        end
        return
      else

        flash[:error] = "Unknown operation #{operation}"

    end

    redirect_to :action => :index
  end
  
  def extract
    success = failure = 0
    params[:filelist].each do |file|
      userfile = SingleFile.new(:name  => File.basename(file))
      Dir.chdir(current_user.vault_dir) do
        userfile.content = File.read(file)
        userfile.user_id = current_user.id
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
