# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base #:nodoc:

  Revision_info="$Id$"

  helper :all # include all helpers, all the time  

  # See ActionController::RequestForgeryProtection for details
  # Uncomment the :secret if you're not using the cookie session store
  #protect_from_forgery # :secret => '1ffec2733b8e6fe4baef5e8b84db95b8'
  
  # See ActionController::Base for details 
  # Uncomment this to filter the contents of submitted sensitive data parameters
  # from your application log (in this case, all fields with names like "password"). 
  # filter_parameter_logging :password
  
  private
  
  def find_or_initialize_task
    if params[:id]
      if @task = DrmaaTask.find_by_id(params[:id], :conditions => { :bourreau_id => CBRAIN::BOURREAU_ID } )
        @task.update_status
      else
        render_optional_error_file :not_found
      end
    else
      # This is all fuzzy logic trying to figure out the
      # expected real class for the new object, based on
      # the content of the keys and values of params
      subtypes = params.keys.select { |x| x =~ /^drmaa_/i }
      subtypekey  = subtypes[0] # hopefully just one
      if subtypekey && subtypehash = params[subtypes[0]]
        subtype  = subtypehash[:type]
      end
      if !subtype && subtypekey # try another way
        subtype = subtypekey.camelize.sub(/^drmaa_/i,"Drmaa")
      end
      @task = Class.const_get(subtype).new(subtypehash)
    end
  end
end
