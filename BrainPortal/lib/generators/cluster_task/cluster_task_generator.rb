class ClusterTaskGenerator < Rails::Generator::NamedBase
  default_options :no_view => false
    
  def manifest        
    task_manifest = record do |m|
      m.template "model.rb", "app/models/drmaa_#{file_name}.rb"
      m.template "partial.html.erb", "app/views/tasks/_drmaa_#{file_name}.html.erb" unless options[:no_view]
    end
    
    puts '-' * 70
    puts ""
    puts "Add the following line to the 'Operations' menu in app/views/userfiles/index.html.erb"
    puts %(  <option value="Drmaa#{class_name}">Launch #{class_name}</option>)
    puts ""
    puts '-' * 70
    puts ""
    
    task_manifest
  end
  
  def add_options!(opt)
    opt.separator ''
    opt.separator 'Options:'
    opt.on("--no-view", 
           "Skip creation of argument input view (if task does not require arguments)") { |v| options[:no_view] = true }
  end
  
  def banner
    "Usage: script/generate cluster_task TaskName [options]"
  end
  
end