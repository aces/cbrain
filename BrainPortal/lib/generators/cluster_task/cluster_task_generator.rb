class ClusterTaskGenerator < Rails::Generator::NamedBase
    
  Revision_info="$Id$"

  def manifest        
    task_manifest = record do |m|
      m.directory "app/models/cbrain_task/#{file_name}"
      m.directory "app/models/cbrain_task/#{file_name}/portal"
      m.directory "app/models/cbrain_task/#{file_name}/bourreau"
      m.template "portal_task_model.rb",  "app/models/cbrain_task/#{file_name}/portal/#{file_name}.rb"
      m.template "cluster_task_model.rb", "app/models/cbrain_task/#{file_name}/bourreau/#{file_name}.rb"
      m.template "partial.html.erb",      "app/views/tasks/cbrain_task/_#{file_name}.html.erb"
      m.template "show_params.html.erb",  "app/views/tasks/show_params/_#{file_name}.html.erb"
      m.template "task_options.html",     "public/doc/tasks/#{file_name}_options.html"
     if File.exists?("app/models/cbrain_task/#{file_name}.rb")
       logger.exists "app/models/cbrain_task/#{file_name}.rb"
     else
       logger.create "app/models/cbrain_task/#{file_name}.rb"
       File.symlink  "cbrain_task_class_loader.rb", "app/models/cbrain_task/#{file_name}.rb"
     end
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
