class ClusterTaskGenerator < Rails::Generator::NamedBase

  Revision_info="$Id$"
    
  def manifest        
    task_manifest = record do |m|
      m.template "drmaa_TEMPLATE.rb", "app/models/drmaa_#{file_name}.rb"
    end
    
    puts '-' * 70
    puts ""
    if options[:command] == :destroy
      puts "Remove the following line from config/routes.rb:"
    else
      puts "Add the following line to config/routes.rb:"
    end
    puts %(  map.resources :drmaa_#{ table_name },  :controller => :tasks )
    puts ""
    puts '-' * 70
    puts ""
    
    task_manifest
  end
  
  def banner
    "Usage: script/generate cluster_task TaskName [options]"
  end
  
end
