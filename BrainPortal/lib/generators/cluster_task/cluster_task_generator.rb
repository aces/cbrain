class ClusterTaskGenerator < Rails::Generator::NamedBase
    
  Revision_info="$Id$"

  def manifest        
    task_manifest = record do |m|
      m.template "portal_task_model.rb", "app/models/cbrain_task/#{file_name}.rb"
      m.template "partial.html.erb",     "app/views/tasks/cbrain_task/_#{file_name}.html.erb"
      m.template "show_params.html.erb", "app/views/tasks/show_params/_#{file_name}.html.erb"
    end
    task_manifest
  end
  
  def add_options!(opt)
    opt.separator ''
    opt.separator 'Options:'
    opt.on("--advanced", "Include the advanced PortalTask API methods in the template.") do |v|
       options[:advanced] = true
    end
  end
  
end
