class ClusterTaskGenerator < Rails::Generators::Base
    
  Revision_info=CbrainFileRevision[__FILE__]

  source_root File.expand_path("../templates", __FILE__)

  argument     :file_name, :type => :string,  :default => "application"  
  class_option :advanced,  :type => :boolean, :default => false

  def create_task
    empty_directory "cbrain_plugins/cbrain_task/#{file_name}"
    empty_directory "cbrain_plugins/cbrain_task/#{file_name}/portal"
    empty_directory "cbrain_plugins/cbrain_task/#{file_name}/bourreau"
    empty_directory "cbrain_plugins/cbrain_task/#{file_name}/views"
    template "portal_task_model.rb",  "cbrain_plugins/cbrain_task/#{file_name}/portal/#{file_name}.rb"
    template "cluster_task_model.rb", "cbrain_plugins/cbrain_task/#{file_name}/bourreau/#{file_name}.rb"
    template "partial.html.erb",      "cbrain_plugins/cbrain_task/#{file_name}/views/_task_params.html.erb"
    template "show_params.html.erb",  "cbrain_plugins/cbrain_task/#{file_name}/views/_show_params.html.erb"
    template "task_options.html",     "public/doc/tasks/#{file_name}_options.html"
    if File.exists?("cbrain_plugins/cbrain_task/#{file_name}.rb")
      #logger.exists "cbrain_plugins/cbrain_task/#{file_name}.rb"
    else
      #logger.create "cbrain_plugins/cbrain_task/#{file_name}.rb"
      File.symlink  "cbrain_task_class_loader.rb", "cbrain_plugins/cbrain_task/#{file_name}.rb"
    end
  end

  def class_name
    file_name.classify
  end
  
end
