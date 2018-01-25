
module AuthenticatedSystem #:nodoc:

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  protected

    # Extract the API token from the params, leaves it in @cbrain_api_token
    def extract_api_token
      @cbrain_api_token = params.delete(:cbrain_api_token).presence
      true
    end

    # Returns true or false if the user is logged in.
    # Preloads @current_user with the user model if they're logged in.
    def logged_in?
      !!current_user
    end

    # Returns the currently logged-in user, if any.
    def current_user
      return @current_user if @current_user.present?
      return nil if @current_user == false # false means we previously explicitely set current_user=(nil)
      user ||= user_from_api_token
      user ||= user_from_session
      self.current_user=user # user can be nil, in that case @current_user is set to false
      @current_user.presence # transforms false into nil
    end

    # Store the given user id in the cookie session. This makes the +new_user+
    # permanently logged-in. If +new_user+ is nil then
    # we record that the current user is unset, therefore marking the
    # session as not logged in.
    def current_user=(new_user)
      session[:user_id] = new_user.try(:id) unless @cbrain_api_token
      @current_user = new_user || false # the false value is important: it means we know we have no user.
    end

    # Check if the user is authorized
    #
    # Override this method in your controllers if you want to restrict access
    # to only a few actions or if you want to check if the user
    # has the correct rights.
    #
    # Example:
    #
    #  # only allow nonbobs
    #  def authorized?
    #    current_user.login != "bob"
    #  end
    def authorized?
      logged_in?
    end

    # Filter method to enforce a login requirement.
    #
    # To require logins for all actions, use this in your controllers:
    #
    #   before_filter :login_required
    #
    # To require logins for specific actions, use this in your controllers:
    #
    #   before_filter :login_required, :only => [ :edit, :update ]
    #
    # To skip this in a subclassed controller:
    #
    #   skip_before_filter :login_required
    #
    def login_required
      authorized? || access_denied
    end

    # Filter method to enforce a site requirement for a controller action.
    # A NormalUser must be a member of a site to proceed.
    def site_membership_required
      (!current_user.site.nil? || access_error(401)) if current_user.has_role?(:normal_user)
    end


    ##########################################################
    #NEXT TWO ADDED BY TAREK
    ##########################################################

    # Before filter to ensure that logged in User is an admin user.
    def admin_role_required
      current_user.has_role?(:admin_user) || access_error(401)
    end

    # Before filter to ensure that logged in User is a site manager (or admin).
    def manager_role_required
      current_user.has_role?(:site_manager) || current_user.has_role?(:admin_user) || access_error(401)
    end

    #Before filter to ensure that logged in User is the core admin.
    def core_admin_role_required
      current_user.has_role?(:core_admin) || access_error(401)
    end

    ##########################################################
    ##########################################################

    # Redirect as appropriate when an access request fails.
    #
    # The default action is to redirect to the login screen.
    #
    # Override this method in your controllers if you want to have special
    # behavior in case the user is not authorized
    # to access the requested action.  For example, a popup window might
    # simply close itself.
    def access_denied(message = 'You must login to see this page.')
      respond_to do |format|
        format.html do
          store_location
          flash[:error] = message
          redirect_to new_session_path
        end
        format.any do
          head :unauthorized
        end
      end
    end

    # Store the URI of the current request in the session.
    #
    # We can return to this location by calling #redirect_back_or_default.
    def store_location
      if request.method == :get
        session[:return_to] = request.fullpath #request.request_uri
      end
    end

    # Redirect to the URI stored by the most recent store_location call or
    # to the passed default.
    def redirect_back_or_default(default)
      redirect_to(session[:return_to] || default)
      session[:return_to] = nil
    end

    # Inclusion hook to make #current_user and #logged_in?
    # available as ActionView helper methods.
    def self.included(base)
      base.send :helper_method, :current_user, :logged_in?
      base.class_eval do
        before_action :extract_api_token
      end
    end

    # Called from #current_user.  First attempt to login by the user id stored in the session.
    def user_from_session
      User.find_by_id(session[:user_id]) if session[:user_id]
    end

    # For API calls. A +cbrain_api_token+ is expected in the params.
    # If the token is valid, the cbrain_session object will contain
    # a proper LargeSessionInfo object from which the token's user
    # can be found.
    def user_from_api_token
      return nil unless @cbrain_api_token
      user = cbrain_session.user_for_cbrain_api(@cbrain_api_token)
      #@cbrain_api_token = nil unless user # invalid, just reset it
      user
    end

end

