class UsersController < ApplicationController
  before_filter :login_required, :admin_role_required
  
  def index
    @users = User.find(:all)

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @users }
    end
  end

  # render new.rhtml
  def new
    @groups = Group.find(:all)
  end
  
  def edit
    @user = User.find(params[:id])
    @groups = Group.find(:all)
  end 

  def create
    cookies.delete :auth_token
    # protects against session fixation attacks, wreaks havoc with 
    # request forgery protection.
    # uncomment at your own risk
    # reset_session
    
    @user = User.new(params[:user])
    @user.save
    
    if @user.errors.empty?
      redirect_to(users_url)
      flash[:notice] = "User successfully created."
    else
      @groups = Group.find(:all)
      render :action => 'new'
    end
  end

  # PUT /users/1
  # PUT /users/1.xml
  def update
    @user = User.find(params[:id])
    @user.groups.delete_all
    
    respond_to do |format|
      if @user.update_attributes(params[:user])        
        flash[:notice] = 'User was successfully updated.'
        format.html { redirect_to users_path }
        format.xml  { head :ok }
      else
        @groups = Group.find(:all)
        format.html { render :action => "edit" }
        format.xml  { render :xml => @user.errors, :status => :unprocessable_entity }
      end
    end
  end

  def destroy
    @user = User.find(params[:id])
    @user.destroy

    respond_to do |format|
      format.html { redirect_to(users_url) }
      format.xml  { head :ok }
    end
  end
end
