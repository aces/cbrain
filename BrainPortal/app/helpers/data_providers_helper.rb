module DataProvidersHelper
  Revision_info="$Id$"
  
  def class_param_for_name(name, klass=Userfile)
    matched_class = klass.send(:subclasses).unshift(klass).find{ |c| name =~ c.file_name_pattern }
    
    if matched_class
      "#{matched_class.name}-#{name}"
    else
      nil
    end
  end
end