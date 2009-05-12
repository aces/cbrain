class Session
  def initialize(session)
    @session = session
    @session[:current_filters] ||= []
    @session[:pagination] ||= 'on'
    @session[:order] ||= 'lft'
  end
  
  def update(params)
    filter = Userfile.get_filter_name(params[:search_type], params[:search_term])   
    @session[:current_filters] = [] if params[:search_type] == 'none'
    @session[:current_filters] |= [filter] unless filter.blank?
    @session[:current_filters].delete params[:remove_filter] if params[:remove_filter]
    
    if params[:view_all] && User.find(@session[:user_id]).has_role?(:admin)
      @session[:view_all] = params[:view_all]
    end
    
    if params[:order] && !params[:page]
      @session[:order] = Userfile.set_order(params[:order], @session[:order])
    end
        
    if params[:pagination]
      @session[:pagination] = params[:pagination]
    end
  end
  
  def paginate?
    @session[:pagination] == 'on'
  end
  
  def view_all?
    @session[:view_all] == 'on' && User.find(@session[:user_id]).has_role?(:admin)
  end
  
  def method_missing(key, *args)
    @session[key.to_sym]
  end
  
end