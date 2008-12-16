
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
    
    unless params[:view_all] && current_user.has_role?(:admin)
      @userfiles = current_user.userfiles.find(:all)
    else
      @userfiles = Userfile.find(:all)
    end
    
    @userfiles = Userfile.apply_filters(@userfiles, session[:current_filters])
    @search_term = params[:search_term] if params[:search_type] == 'name_search'
    
    
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
    if upload_stream == "" || upload_stream.nil?
      redirect_to :action => :index
      return
    end

    userfile         = Userfile.new()
    clean_basename   = File.basename(upload_stream.original_filename)

    if current_user.userfiles.exists?(:name => clean_basename)
        flash[:error] = "File '" + clean_basename + "' already exists."
        redirect_to :action => :index
        return
    end

    userfile.content = upload_stream.read   # also fills file_size
    userfile.name    = clean_basename
    userfile.user_id = current_user.id
    
    if userfile.name =~ /\.tar(\.gz)?$/
      success, filenames = userfile.extract
      if success
        flash[:notice] = filenames.map{|f| "File #{f} added."}.join("\n")
      else
        flash[:error]  = "Some or all of the files were not extracted properly (internal error?).\n"
      end
    else
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
        flash[:notice] = 'Userfile was successfully updated.'
        format.html { redirect_to(userfiles_url(:view_all  => params[:view_all])) }
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

    # TODO: filter out right away from the filelist IDs that do not belong to the user
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
        if filelist.size == 1
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
  
end
