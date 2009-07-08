
#
# CBRAIN Project
#
# Bourreau controller for the BrainPortal interface
#
# Original author: Pierre Rioux
#
# $Id$
#

class BourreauxController < ApplicationController

  Revision_info="$Id$"

  before_filter :login_required
   
  def index
    @bourreaux = Bourreau.all;
    if ! check_role(:admin)
      @bourreaux = @bourreaux.select { |p| p.can_be_accessed_by(current_user) }
    end
  end

  # GET /bourreaux/1
  # GET /bourreaux/1.xml
  def show
    @bourreau = Bourreau.find(params[:id])

    raise "Bourreau not accessible by current user." unless @bourreau.can_be_accessed_by(current_user)

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @bourreau }
    end

  #rescue
  #  access_error(404)
  end
  
  def edit
    @user     = current_user

    if !check_role(:admin)
       flash[:error] = "Only admins can edit a bourreau."
       redirect_to :action => :index
       return
    end

    @bourreau = Bourreau.find(params[:id])

    respond_to do |format|
      format.html { render :action => :edit }
      format.xml  { render :xml => @bourreau }
    end

  rescue
    access_error(404)
  end

  def new
    @user     = current_user

    if !check_role(:admin)
       flash[:error] = "Only admins can create a bourreau."
       redirect_to :action => :index
       return
    end

    @bourreau = Bourreau.new( :user_id   => @user.id,
                              :group_id  => Group.find_by_name(@user.login).id,
                              :online    => true
                            )

    respond_to do |format|
      format.html { render :action => :new }
      format.xml  { render :xml => @bourreau }
    end

  #rescue
  #  access_error(404)
  end

  def create

    if !check_role(:admin)
       flash[:error] = "Only admins can create a bourreau."
       redirect_to :action => :index
       return
    end

    @user     = current_user
    fields    = params[:bourreau]

    @bourreau = Bourreau.new( fields )
    @bourreau.save

    if @bourreau.errors.empty?
      redirect_to(bourreaux_url)
      flash[:notice] = "Bourreau successfully created."
    else
      render :action => :new
      return
    end

  rescue
    access_error(404)
  end

  def update

    if !check_role(:admin)
       flash[:error] = "Only admins can modify a bourreau."
       redirect_to :action => :index
       return
    end

    @user     = current_user
    id        = params[:id]
    @bourreau = Bourreau.find_by_id(id)

    fields    = params[:bourreau]
    subtype   = fields.delete(:type)

    @bourreau.update_attributes(fields)

    @bourreau.save

    if @bourreau.errors.empty?
      redirect_to(bourreaux_url)
      flash[:notice] = "Bourreau successfully updated."
    else
      render :action => 'edit'
      return
    end

  rescue
    access_error(404)
  end

  def destroy

    if !check_role(:admin)
       flash[:error] = "Only admins can destroy a bourreau."
       redirect_to :action => :index
       return
    end

    id        = params[:id]
    @user     = current_user
    @bourreau = Bourreau.find_by_id(id)

    if @bourreau.destroy
      flash[:notice] = "Bourreau successfully deleted."
    else
      flash[:error] = "Bourreau destruction failed."
    end

    redirect_to :action => :index

  rescue
    access_error(404)
  end

end
