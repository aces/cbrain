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
  
  #Patch: Load all models so single-table inheritance works properly.
  begin
    Dir.chdir(File.join(RAILS_ROOT, "app", "models")) do
      Dir.glob("*.rb").each do |model|
        require_dependency model unless Object.const_defined? model.split(".")[0].classify
      end
    end
  rescue => error
    if error.to_s.match(/Mysql::Error.*Table.*doesn't exist/i)
      puts "Skipping model load:\n\t- Database table doesn't exist yet. It's likely this system is new and the migrations have not been run yet."
    elsif error.to_s.match(/Unknown database/i)
      puts "Skipping model load:\n\t- System database doesn't exist yet. It's likely this system is new and the migrations have not been run yet."
    else
      raise
    end
  end

end
