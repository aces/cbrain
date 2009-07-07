class CustomFiltersController < ApplicationController
  
  before_filter :login_required

  # GET /custom_filters/new
  # GET /custom_filters/new.xml
  def new
    @custom_filter = CustomFilter.new
    @user_groups   = current_user.groups
    @user_tags   = current_user.tags

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @custom_filter }
    end
  end

  # GET /custom_filters/1/edit
  def edit
    @custom_filter = CustomFilter.find(params[:id])
    @user_groups   = current_user.groups
    @user_tags   = current_user.tags
  end

  # POST /custom_filters
  # POST /custom_filters.xml
  def create    
    created_date_term = params[:custom_filter].select{ |k,v| k.to_s =~ /^created_date_term/ }.collect{ |e|  e[1]}
      
    @custom_filter = CustomFilter.new(params[:custom_filter])
    @custom_filter.user_id = current_user.id
    @custom_filter.created_date_term = created_date_term
    
    respond_to do |format|
      if @custom_filter.save
        flash[:notice] = "Custom filter '#{@custom_filter.name}' was successfully created."
        format.html { redirect_to(userfiles_path) }
        format.xml  { render :xml => @custom_filter, :status => :created, :location => @custom_filter }
      else
        @user_groups   = current_user.groups  
        @user_tags   = current_user.tags
              
        format.html { render :action => "new" }
        format.xml  { render :xml => @custom_filter.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /custom_filters/1
  # PUT /custom_filters/1.xml
  def update
    @custom_filter = CustomFilter.find(params[:id])

    respond_to do |format|
      if @custom_filter.update_attributes(params[:custom_filter])
        flash[:notice] = "Custom filter '#{@custom_filter.name}' was successfully updated."
        format.html { redirect_to(userfiles_path) }
        format.xml  { head :ok }
      else
        @user_groups   = current_user.groups
        @user_tags   = current_user.tags
        
        format.html { render :action => "edit" }
        format.xml  { render :xml => @custom_filter.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /custom_filters/1
  # DELETE /custom_filters/1.xml
  def destroy
    @custom_filter = CustomFilter.find(params[:id])    
    current_session.current_filters.delete "custom:#{@custom_filter.name}"
    @custom_filter.destroy

    flash[:notice] = "Custom filter '#{@custom_filter.name}' deleted."

    respond_to do |format|
      format.html { redirect_to(userfiles_path) }
      format.xml  { head :ok }
    end
  end
end
