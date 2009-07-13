
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
  before_filter :admin_role_required, :except => [:index]  
   
  def index #:nodoc:
    @bourreaux = Bourreau.all;
    if ! check_role(:admin)
      @bourreaux = @bourreaux.select { |p| p.can_be_accessed_by(current_user) }
    end
  end

  
  def show #:nodoc:
    @bourreau = Bourreau.find(params[:id])

    raise "Bourreau not accessible by current user." unless @bourreau.can_be_accessed_by(current_user)

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @bourreau }
    end

  #rescue
  #  access_error(404)
  end
  
  def edit #:nodoc:
    @user     = current_user
    @bourreau = Bourreau.find(params[:id])

    respond_to do |format|
      format.html { render :action => :edit }
      format.xml  { render :xml => @bourreau }
    end

  rescue
    access_error(404)
  end

  def new  #:nodoc:
    @user     = current_user
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

  def create #:nodoc:
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

  def update #:nodoc:
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

  def destroy #:nodoc:
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
