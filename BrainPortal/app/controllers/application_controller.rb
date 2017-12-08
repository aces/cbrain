class ApplicationController < ActionController::Base

  include AuthenticatedSystem
  include SessionHelpers
  include ViewScopes
  # include PersistentSelection
  include ViewHelpers
  include ApiHelpers
  include PermissionHelpers
  # include ExceptionHelpers
  # include MessageHelpers


#  helper        :all # include all helpers, all the time
  helper_method :start_page_path

  # before_filter :set_cache_killer
  # before_filter :check_account_validity
  # before_filter :prepare_messages
  # before_filter :adjust_system_time_zone
  # around_filter :activate_user_time_zone
  # after_filter  :update_session_info       # touch timestamp of session at least once per minute
  # after_filter  :action_counter            # counts all action/controller/user agents
  # after_filter  :log_user_info             # add to log a single line with user info.

  protect_from_forgery with: :exception

  # Home pages in hash form.
  def start_page_params #:nodoc:
    if current_user.nil?
      { :controller => :sessions, :action => :new }
    elsif current_user.has_role?(:normal_user)
      { :controller => :groups, :action => :index }
    else
      { :controller => :portal, :action => :welcome }
    end
  end

  # Different home pages for admins and other users.
  def start_page_path #:nodoc:
    url_for(start_page_params)
  end
end
