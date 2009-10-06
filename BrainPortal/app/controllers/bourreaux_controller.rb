
#
# CBRAIN Project
#
# Bourreau controller for the BrainPortal interface
#
# Original author: Pierre Rioux
#
# $Id$
#

#RESTful controller for managing the Bourreau (remote execution server) resource. 
#All actions except +index+ require *admin* privileges.
class BourreauxController < ApplicationController

  Revision_info="$Id$"

  before_filter :login_required
  before_filter :manager_role_required, :except  => [:index, :show]
   
  def index #:nodoc:
    @bourreaux = Bourreau.find_all_accessible_by_user(current_user)
  end

  
  def show #:nodoc:
    @bourreau = Bourreau.find(params[:id])

    raise "Execution Server not accessible by current user." unless @bourreau.can_be_accessed_by?(current_user)

    @info = @bourreau.info

    @user_id_name = {}
    User.all.each { |user| @user_id_name[user.id] = user.login }
    
    @user_tasks_info = {}
    begin
       tasks = ActRecTask.all
    rescue
       tasks = []
    end

    @statuses = { 'TOTAL' => 0 }
    tasks.each do |t|
      user_id = t.user_id.to_i
      name    = @user_id_name[user_id] || "User-#{user_id}"
      status  = t.status
      @statuses[status]               ||= 0
      @statuses[status]                += 1
      @statuses['TOTAL']               += 1
      @user_tasks_info[name]          ||= {}
      @user_tasks_info[name][status]  ||= 0
      @user_tasks_info[name][status]   += 1
      @user_tasks_info[name]['TOTAL'] ||= 0
      @user_tasks_info[name]['TOTAL']  += 1
    end
    @statuses_list = @statuses.keys.sort.reject { |s| s == 'TOTAL' }
    @statuses_list << 'TOTAL'

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @bourreau }
    end

  end
  
  def edit #:nodoc:
    @bourreau = Bourreau.find(params[:id])
    
    raise "Execution Server not accessible by current user." unless @bourreau.has_owner_access?(current_user)
    
    @users = current_user.available_users
    @groups = current_user.available_groups

    respond_to do |format|
      format.html { render :action => :edit }
      format.xml  { render :xml => @bourreau }
    end

  end

  def new  #:nodoc:
    @bourreau = Bourreau.new( :user_id   => current_user.id,
                              :group_id  => Group.find_by_name(current_user.login).id,
                              :online    => true
                            )

    respond_to do |format|
      format.html { render :action => :new }
      format.xml  { render :xml => @bourreau }
    end

  end

  def create #:nodoc:
    fields    = params[:bourreau]

    @bourreau = Bourreau.new( fields )
    @bourreau.save

    

    if @bourreau.errors.empty?
      flash[:notice] = "Execution Server successfully created."
    end
   
    respond_to do |format|
      format.js
    end
  end

  def update #:nodoc:
    id        = params[:id]
    @bourreau = Bourreau.find(id)
    
    raise "Execution Server not accessible by current user." unless @bourreau.has_owner_access?(current_user)

    fields    = params[:bourreau]
    subtype   = fields.delete(:type)

    @bourreau.update_attributes(fields)

    @bourreau.save

    if @bourreau.errors.empty?
      redirect_to(bourreaux_url)
      flash[:notice] = "Execution Server successfully updated."
    else
      @users = current_user.available_users
      @groups = current_user.available_groups
      render :action => 'edit'
      return
    end

  end

  def destroy #:nodoc:
    id        = params[:id]
    @bourreau = Bourreau.find(id)
    @destroyed = false
    
    raise "Execution Server not accessible by current user." unless @bourreau.has_owner_access?(current_user)

    tasks_left = 0
    begin
      DrmaaTask.adjust_site(@bourreau.id)
      tasks_left = DrmaaTask.find(:all).size
    rescue
    end
    raise "This Execution Server cannot be deleted as there are still #{tasks_left} tasks associated with it." if tasks_left > 0

    if @bourreau.destroy
      @destroyed = true
      flash[:notice] = "Execution Server successfully deleted."
    else
      flash[:error] = "Execution Server destruction failed."
    end

    respond_to do |format|
      format.js
    end

  end

  def start
    @bourreau = Bourreau.find(params[:id])

    raise "Execution Server not accessible by current user." unless @bourreau.can_be_accessed_by?(current_user)
    raise "Execution Server is not yet configured for remote control." unless @bourreau.has_ssh_control_info?

    raise "This Execution Server is already alive." if @bourreau.is_alive?

    @bourreau.start_tunnels
    raise "Could not start master SSH connection and tunnels." unless @bourreau.ssh_master.is_alive?
    @bourreau.start

    sleep 5+rand(3)
    if @bourreau.is_alive?
      flash[:notice] = "Execution Server started."
    else
      flash[:error] = "Execution Server could not be started."
    end

    redirect_to :action => :index

    rescue => e
       flash[:error] = e.message
       redirect_to :action => :index
  end

  def stop
    @bourreau = Bourreau.find(params[:id])

    raise "Execution Server not accessible by current user." unless @bourreau.can_be_accessed_by?(current_user)
    raise "Execution Server is not yet configured for remote control." unless @bourreau.has_ssh_control_info?

    @bourreau.stop
    @bourreau.ssh_master.stop
    flash[:notice] = "Execution Server stopped. Tunnels stopped."
    redirect_to :action => :index

    rescue => e
       flash[:error] = e.message
       redirect_to :action => :index
  end

end
