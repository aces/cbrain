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

  # This is a before_filter for the tasks controller.
  # It just makes sure some workers are available.
  # It's unfortunate that due to technical reasons,
  # such workers cannot be started when the application
  # boots (CBRAIN.spawn_with_active_records() won't work
  # properly until RAILS is fully booted).
  def start_bourreau_workers
    allworkers = BourreauWorker.all
    return true if allworkers.size > 0
    # For the moment we only start one worker, but
    # in the future we may want to start more than one,
    # once we're sure they dont interfere with each other.
    worker = BourreauWorker.new
    worker.check_interval = 10                          # in seconds, default is 10
    worker.bourreau       = CBRAIN::SelfRemoteResource  # Optional, when logging to Bourreau's log
    worker.log_to         = 'stdout'                    # 'stdout,bourreau'
    worker.verbose        = true                        # if we want each job action logged!
    worker.launch
    true
  end

end
