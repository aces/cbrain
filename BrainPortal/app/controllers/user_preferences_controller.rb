class UserPreferencesController < ApplicationController

  Revision_info="$Id$"
  
  before_filter :login_required
  
  # GET /user_preferences
  # GET /user_preferences.xml
  def index
    @user_preference = current_user.user_preference || UserPreference.create(:user_id => current_user.id)
        
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @user_preference }
    end
  end


  # PUT /user_preferences/1
  # PUT /user_preferences/1.xml
  def update
    @user_preference = current_user.user_preference || UserPreference.create(:user_id => current_user.id)
    @user_preference.update_options(params[:other_options])

    respond_to do |format|
      if @user_preference.update_attributes(params[:user_preference])
        flash[:notice] = 'Preferences successfully updated.'
        format.html { redirect_to(user_preferences_path) }
        format.xml  { head :ok }
      else
        format.html { render :action => "index" }
        format.xml  { render :xml => @user_preference.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /user_preferences/1
  # DELETE /user_preferences/1.xml
  def destroy
    @user_preference = current_user.user_preference || UserPreference.create(:user_id => current_user.id)
    @user_preference.other_options = {}

    respond_to do |format|
      if @user_preference.save
        flash[:notice] = 'Preferences successfully reset.'
        format.html { redirect_to(user_preferences_url) }
        format.xml  { head :ok }
      else
        flash.now[:error] = 'Preferences successfully reset.'
        format.html { render :action => "index" }
        format.xml  { render :xml => @user_preference.errors, :status => :unprocessable_entity }
      end 
    end
  end
end
