class ClusterTaskGenerator < Rails::Generator::NamedBase
    
  Revision_info=CbrainFileRevision[__FILE__]

  def manifest        
    task_manifest = record do |m|
      m.directory "cbrain_plugins/cbrain_task/#{file_name}"
      m.directory "cbrain_plugins/cbrain_task/#{file_name}/portal"
      m.directory "cbrain_plugins/cbrain_task/#{file_name}/bourreau"
      m.directory "cbrain_plugins/cbrain_task/#{file_name}/views"
      m.template "portal_task_model.rb",  "cbrain_plugins/cbrain_task/#{file_name}/portal/#{file_name}.rb"
      m.template "cluster_task_model.rb", "cbrain_plugins/cbrain_task/#{file_name}/bourreau/#{file_name}.rb"
      m.template "partial.html.erb",      "cbrain_plugins/cbrain_task/#{file_name}/views/_task_params.html.erb"
      m.template "show_params.html.erb",  "cbrain_plugins/cbrain_task/#{file_name}/views/_show_params.html.erb"
      m.template "task_options.html",     "public/doc/tasks/#{file_name}_options.html"
     if File.exists?("cbrain_plugins/cbrain_task/#{file_name}.rb")
       logger.exists "cbrain_plugins/cbrain_task/#{file_name}.rb"
     else
       logger.create "cbrain_plugins/cbrain_task/#{file_name}.rb"
       File.symlink  "cbrain_task_class_loader.rb", "cbrain_plugins/cbrain_task/#{file_name}.rb"
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
