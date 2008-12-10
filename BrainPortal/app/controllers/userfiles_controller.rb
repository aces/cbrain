
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
    @userfiles = current_user.userfiles.search(params[:search_type], params[:search_term])
    @search_term = params[:search_term] if params[:search_type] == 'name_search'
  
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @userfiles }
    end
  end

  # GET /userfiles/1
  # GET /userfiles/1.xml
  def show
    @userfile = current_user.userfiles.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @userfile }
    end
  #rescue
   #access_error("File doesn't exist or you do not have permission to access it.", 404)
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
    @userfile = current_user.userfiles.find(params[:id])
    @tags = current_user.tags.find(:all)
  rescue
    access_error("File doesn't exist or you do not have permission to access it.", 404)
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

    if userfile.save
      flash[:notice] = "File '" + clean_basename + "' added."
    else
      flash[:error]  = "File '" + clean_basename + "' could not be added (internal error?)."
    end

    redirect_to :action => :index
  end

  # PUT /userfiles/1
  # PUT /userfiles/1.xml
  def update
    @userfile = current_user.userfiles.find(params[:id])

    respond_to do |format|
      if @userfile.update_attributes(params[:userfile])
        flash[:notice] = 'Userfile was successfully updated.'
        format.html { redirect_to(@userfile) }
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
          userfile = current_user.userfiles.find(id)
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
          userfile = current_user.userfiles.find(id)
          if userfile.nil?
            flash[:error] += "File #{id} doesn't exist or is not yours.\n"
            next
          end
          basename = userfile.name
          userfile.destroy
          flash[:notice] += "File #{basename} deleted.\n"
        end

      when "wait"

        sleep 20
        flash[:error] = "Slept for some time\n"

      else

        flash[:error] = "Unknown operation #{operation}"

    end

    redirect_to :action => :index
  end
  
end
