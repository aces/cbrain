
#
# CBRAIN Project
#
# Data Provider controller for the BrainPortal interface
#
# Original author: Pierre Rioux
#
# $Id$
#

#Restful controller for the DataProvider resource.
class DataProvidersController < ApplicationController

  Revision_info="$Id$"

  before_filter :login_required
   
  def index #:nodoc:
    @providers = DataProvider.all;
    unless check_role(:admin)
        @providers = @providers.select { |p| p.can_be_accessed_by(current_user) }
    end
  end

  # GET /data_providers/1
  # GET /data_providers/1.xml
  def show  #:nodoc:
    @provider = DataProvider.find(params[:id])

    raise "Provider not accessible by current user." unless @provider.can_be_accessed_by(current_user)

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @provider }
    end

  rescue
    access_error(404)
  end
  
  def edit #:nodoc:
    @provider = DataProvider.find(params[:id])
    @user     = current_user
    #@mode     = "update"

    if !check_role(:admin) && @provider.user_id != @user.id
       flash[:error] = "You cannot edit a provider that you do not own."
       redirect_to :action => :index
       return
    end

    respond_to do |format|
      format.html { render :action => :edit }
      format.xml  { render :xml => @provider }
    end

  rescue
    access_error(404)
  end

  def new #:nodoc:
    @user     = current_user
    @provider = DataProvider.new( :user_id   => @user.id,
                                  :group_id  => Group.find_by_name(@user.login).id,
                                  :online    => true,
                                  :read_only => false
                                )
    #@mode     = "create"

    respond_to do |format|
      format.html { render :action => :new }
      format.xml  { render :xml => @provider }
    end

  rescue
    access_error(404)
  end

  def create #:nodoc:
    @user     = current_user
    fields    = params[:data_provider]
    subtype   = fields.delete(:type)

    if subtype.empty?
      @provider = DataProvider.new( fields )
      flash[:error] = "You must specify a type for your provider."
      render :action => :new
      return
    end

    subclass  = Class.const_get(subtype)

    if subtype == "DataProvider" || ! (subclass < DataProvider)
      @provider = DataProvider.new( fields )
      flash[:error] = "Provider class not a Data Provider?!?"
      render :action => :new
      return
    end

    @provider = subclass.new( fields )
    @provider.save

    if @provider.errors.empty?
      redirect_to(data_providers_url)
      flash[:notice] = "Provider successfully created."
    else
      #@mode = "update"
      render :action => :new
      return
    end

  rescue
    access_error(404)
  end

  def update #:nodoc:

    @user     = current_user
    id        = params[:id]
    @provider = DataProvider.find(id)

    if !check_role(:admin) && @provider.user_id != @user.id
       flash[:error] = "You cannot edit a provider that you do not own."
       redirect_to :action => :index
       return
    end

    fields    = params[:data_provider]
    subtype   = fields.delete(:type)

    @provider.update_attributes(fields)

    if @provider.errors.empty?
      redirect_to(data_providers_url)
      flash[:notice] = "Provider successfully updated."
    else
      #@mode = "update"
      render :action => 'edit'
      return
    end

  rescue
    access_error(404)
  end

  def destroy #:nodoc:
    id        = params[:id]
    @user     = current_user
    @provider = DataProvider.find(id)

    userfiles = Userfile.find(:all, :conditions => { :data_provider_id => id })
    if ! userfiles.empty?
      flash[:error] = "You cannot remove a provider that has still files registered on it."
      redirect_to :action => :show, :id => id
      return
    end

    if check_role(:admin) || @provider.user_id == @user.id
      @provider.destroy
      flash[:notice] = "Provider successfully deleted."
    else
      flash[:error] = "You cannot remove a provider that you do not own."
    end

    redirect_to :action => :index

  rescue
    access_error(404)
  end

  #Browse the files of a data provider.
  #This action is only available for data providers that are browsable.
  #Both registered and unregistered files will appear in the list. 
  #Unregistered files can be registered here.
  def browse
    @user     = current_user
    id        = params[:id]
    @provider = DataProvider.find(id)

    if (!check_role(:admin) && ! @provider.can_be_accessed_by(@user)) || ! @provider.is_browsable?
      flash[:error] = "You cannot browse this provider."
      redirect_to :action => :index
      return
    end

    begin
      # [ base, size, type, mtime ]
      @rawlist = @provider.provider_list_all
    rescue => e
      flash[:error] = "Cannot get list of files: #{e.to_s}"
      redirect_to :action => :index
      return
    end

    @rawlist.each do |tuplet|
      tupname  = tuplet[0]
      tupsize  = tuplet[1]
      tuptype  = tuplet[2]
      tupmtime = tuplet[3]
      registered = Userfile.find(:first, :conditions => { :name => tupname, :data_provider_id => @provider.id})
      if registered
        tuplet << registered  #userfile
        if ((tuptype == :regular    && registered.is_a?(SingleFile)) ||
            (tuptype == :directory  && registered.is_a?(FileCollection)))
          tuplet << "" # message
        else
          tuplet << "Conflicting types!"
        end
      else
        tuplet << nil   # userfile is nil
        tuplet << nil   # message
      end
    end

  #rescue
  #  access_error(404)
  end

  #Register a given file into the system.
  #The file's meta data will be saved as a Userfile resource.
  def register
    @user        = current_user
    user_id      = @user.id
    provider_id  = params[:id]
    @provider    = DataProvider.find(provider_id)

    if (!check_role(:admin) && ! @provider.can_be_accessed_by(@user)) || ! @provider.is_browsable?
      flash[:error] = "You cannot register files from this provider."
      redirect_to :action => :index
      return
    end

    basenames = params[:basenames] || []
    dirtypes  = params[:directorytypes] || []
    do_unreg  = params[:commit] =~ /unregister/i

    base2type = {}
    dirtypes.select { |typebase| ! typebase.empty? }.each do |typebase|
      next unless typebase.match(/^(\w+)-(\S+)$/)
      type = $1
      base = $2
      base2type[base] = type
    end
    
    num_registered   = 0
    num_unregistered = 0
    num_skipped      = 0

    flash[:error]  = ""
    flash[:notice] = ""

    basenames.each do |basename|

      # Unregister old files

      if do_unreg
        unless userfile = Userfile.find(:first, :conditions => { :name => basename, :data_provider_id => provider_id } )
          num_skipped += 1
          next
        end
        num_unregistered += Userfile.delete(userfile.id)
        next
      end

      # Register new files

      subtype = "SingleFile"
      if base2type.has_key?(basename)
        subtype = base2type[basename]
        if subtype == "Unset" || (subtype != "FileCollection" && subtype != "CivetCollection")
           flash[:error] += "Error: subdirectory #{basename} not provided with a proper type. File not registered.\n"
           num_skipped += 1
           next
        end
      end

      subclass = Class.const_get(subtype)
      userfile = subclass.new( :name             => basename, 
                               :size             => 0,
                               :user_id          => user_id,
                               :group_id         => @provider.group_id,
                               :data_provider_id => provider_id )
      if userfile.save
        num_registered += 1
      else
        flash[:error] += "Error: could not register #{subtype} '#{basename}'\n"
        num_skipped += 1
      end

    end

    if num_skipped > 0
      flash[:notice] += "Skipped #{num_skipped} files.\n"
    end

    if num_registered > 0
      flash[:notice] += "Registered #{num_registered} files.\n"
    elsif num_unregistered > 0
      flash[:notice] += "Unregistered #{num_unregistered} files.\n"
    else
      flash[:notice] += "No files affected.\n"
    end

    redirect_to :action => :browse
    
  end

end
