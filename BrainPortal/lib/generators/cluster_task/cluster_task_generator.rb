class ClusterTaskGenerator < Rails::Generator::NamedBase
  default_options :no_view => false
    
  def manifest        
    task_manifest = record do |m|
      m.template "model.rb", "app/models/drmaa_#{file_name}.rb"
      m.template "partial.html.erb", "app/views/tasks/_drmaa_#{file_name}.html.erb" unless options[:no_view]
    end
    
    puts '-' * 70
    puts ""
    if options[:command] == :destroy
      puts "Remove the following line (or whatever it was changed to) from the 'Operations' menu in" 
    else
      puts "Add the following line to the 'Operations' menu in"
    end
    puts "app/views/userfiles/_tool_management_conversion.html.erb (if this is a conversion tool)"
    puts "OR"
    puts "app/views/userfiles/_tool_management_scientific.html.erb (if this is any other type of tool):"
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