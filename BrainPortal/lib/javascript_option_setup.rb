module JavascriptOptionSetup
  private
  
  def options_setup(element_class, options)
    options[:class] ||= ""
    options[:class] +=  " #{element_class}"
    
    url = options.delete(:url)
    if url
      options["data-url"] = url
    end
    
    data_type = options.delete(:datatype)
    if data_type
      options["data-type"] = data_type.to_s.downcase
    end
    
    method = options.delete(:method)
    if method
      options["data-method"] = method.to_s.upcase
    end
    
    target = options.delete(:target)
    if target
      options["data-target"] = target
    end
    
    update_text = options.delete(:loading_message)
    if update_text
      options["data-loading-message"] = update_text
    end
    
    update_text_target = options.delete(:loading_message_target)
    if update_text_target
      options["data-loading-message-target"] = update_text_target
    end
    
    overlay = options.delete(:overlay)
    if overlay && overlay.to_s.downcase != "false"
      options["data-target"] = "__OVERLAY__"
    end
    
    confirm = options.delete(:confirm)
    if confirm
      options["data-confirm"] = confirm
    end
    
    width = options.delete(:width)
    if width
      options["data-width"] = width
    end
    
    height = options.delete(:height)
    if height
      options["data-height"] = height
    end
    
    error_message = options.delete(:error_message)
    if error_message
      options["data-error"] = h(error_message)
    end
    
    replace = options.delete(:replace)
    if replace
      options["data-replace"] = replace
    end
  end
  
end
