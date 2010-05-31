class ClusterTaskGenerator < Rails::Generator::NamedBase

  Revision_info="$Id$"
    
  def manifest        
    task_manifest = record do |m|
      m.template "cluster_task_model.rb", "app/models/cbrain_task/#{file_name}.rb"
    end
    task_manifest
  end
  
end
