class ClusterTaskGenerator < Rails::Generator::NamedBase
    
  def manifest        
    record do |m|
      m.template "drmaa_TEMPLATE.rb", "app/models/drmaa_#{file_name}.rb"
    end
  end
  
  def banner
    "Usage: script/generate cluster_task TaskName [options]"
  end
  
end