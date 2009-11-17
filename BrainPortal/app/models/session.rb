
#
# CBRAIN Project
#
# Model for the current session.
#
# Original author: Tarek Sherif
#
# $Id$
#

#Model represeting the current session. The current session object can 
#be accessed using the <b><tt>current_session</tt></b> method of the ApplicationController
#class.
#
#This model is meant to act as a wrapper around the session hash.
#It takes care of updating the values of and performing any logic related 
#to the following attributes of the current session (mainly related
#to the Userfile index page):
#* currently active filters.
#* whether or not pagination is active.
#* current ordering of the Userfile index.
#* whether to view current user's files or all files on the system (*admin* only).
#
#Session attributes can be accessed by calling methods with the attribute name.
#*Example*: calling +current_session+.+current_filters+ will access <tt>session[:current_filters]</tt>
#
#*Note*: this is not a database-backed model.
class Session

  Revision_info="$Id$"

  def initialize(session, params) #:nodoc:
    @session = session
    @session[:userfiles_basic_filters] ||= []
    @session[:userfiles_tag_filters] ||= []
    @session[:userfiles_custom_filters] ||= []
    @session[:userfiles_pagination] ||= 'on'
    @session[:userfiles_sort_order] ||= 'userfiles.lft'
    
    controller = params[:controller]
    @session[controller.to_sym] ||= {}
    @session[controller.to_sym]["filters"] ||= {}
    @session[controller.to_sym]["sort"] ||= {}
  end
  
  #Update attributes of the session object based on the incoming request parameters
  #contained in the +params+ hash.
  def update(params)
    controller = params[:controller]

    filter = Userfile.get_filter_name(params[:userfiles_search_type], params[:userfiles_search_term])   
    if params[:userfiles_search_type] == 'unfilter'
      @session[:userfiles_basic_filters] = []
      @session[:userfiles_tag_filters] = []
      @session[:userfiles_custom_filters] = []
    else
      @session[:userfiles_basic_filters] |= [filter] unless filter.blank?
      @session[:userfiles_tag_filters] |= [params[:userfiles_tag_filter]] unless params[:userfiles_tag_filter].blank?
      @session[:userfiles_custom_filters] |= [CustomFilter.find(params[:userfiles_custom_filter]).name] unless params[:userfiles_custom_filter].blank?
      @session[:userfiles_basic_filters].delete params[:userfiles_remove_basic_filter] if params[:userfiles_remove_basic_filter]
      @session[:userfiles_custom_filters].delete params[:userfiles_remove_custom_filter] if params[:userfiles_remove_custom_filter]
      @session[:userfiles_tag_filters].delete params[:userfiles_remove_tag_filter] if params[:userfiles_remove_tag_filter]
    end
        
    if params[:userfiles_view_all] && (User.find(@session[:user_id]).has_role?(:admin) || User.find(@session[:user_id]).has_role?(:site_manager))
      @session[:userfiles_view_all] = params[:userfiles_view_all]
    end
    
    if params[:userfiles_sort_order] && !params[:page]
      @session[:userfiles_sort_order] = params[:userfiles_sort_order]
      @session[:userfiles_sort_dir] = params[:userfiles_sort_dir]
    end
        
    if params[:userfiles_pagination]
      @session[:userfiles_pagination] = params[:userfiles_pagination]
    end
        
    if params[controller]
      if params[controller]["filter_off"]
        @session[controller.to_sym]["filters"] = {}
      elsif params[controller]["remove_filter"]
        @session[controller.to_sym]["filters"].delete(params[controller]["remove_filter"])
      else
        @session[controller.to_sym]["filters"].merge!(params[controller]["filters"] || {})
        @session[controller.to_sym]["sort"] = params[controller]["sort"] || {}
      end
    end
  end
  
  #Is pagination of the Userfile index currently active?
  def paginate?
    @session[:userfiles_pagination] == 'on'
  end
  
  #Is the current *admin* user viewing all files on the system (or only his/her own)?
  def view_all?
    @session[:userfiles_view_all] == 'on' && (User.find(@session[:user_id]).has_role?(:admin) || User.find(@session[:user_id]).has_role?(:site_manager))
  end
  
  def params_for(controller)
    @session[controller.to_sym]
  end
  
  def [](key)
    @session[key]
  end
  
  def []=(key, value)
    @session[key] = value
  end
  
  #The method_missing method has been redefined to allow for simplified access to session parameters.
  #
  #*Example*: calling +current_session+.+current_filters+ will access <tt>session[:current_filters]</tt>
  def method_missing(key, *args)
    @session[key.to_sym]
  end
  
end
