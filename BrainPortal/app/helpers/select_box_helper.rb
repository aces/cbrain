#Helper methods for resource select boxes.
module SelectBoxHelper

  Revision_info="$Id$"
  
  #################################################################################
  # Selector Helpers
  #################################################################################
  
  def grouped_options_for_select(grouped_options, selected_key = nil, prompt = nil)
    body = ''
    body << content_tag(:option, prompt, :value => "") if prompt
  
    grouped_options = grouped_options.sort if grouped_options.is_a?(Hash)
  
    grouped_options.each do |group|
      body << content_tag(:optgroup, options_for_select(group[1], selected_key), :label => group[0])
    end
  
    body
  end
  
  #Create a standard user select box for selecting a user id for a form.
  #The +parameter_name+ argument will be the name of the parameter 
  #when the form is submitted. and the +select_tag_options+ hash will be sent
  #directly as options to the +select_tag+ helper method called to create the element.
  #The +options+ hash can contain contain either or both of the following:
  #[selector] used for default selection. This can be a User object, a user id (String or Fixnum),
  #           or any model that has a user_id attribute.
  #[users] the array of User objects used to build the select box. Defaults to +current_user.available_users+.
  def user_select(parameter_name = "user_id", options = {}, select_tag_options = {} )
    options  = { :selector => options } unless options.is_a?(Hash)
    selector = options[:selector]
    users    = options[:user] || current_user.available_users
  
    if selector.respond_to?(:user_id)
      selected = selector.user_id.to_s
    elsif selector.is_a?(User)
      selected = selector.id.to_s
    else
      selected = selector.to_s
    end
    grouped_options = options_for_select(users.sort_by(&:login).collect { |u| [ u.login, u.id.to_s ] }, selected || current_user.id.to_s)
    blank_label = select_tag_options.delete(:include_blank)
    if blank_label
      blank_label = "" if blank_label == true
      grouped_options = "<option value=\"\">#{blank_label}</option>" + grouped_options
    end
    
    select_tag parameter_name, grouped_options, select_tag_options
  end
  
  #Create a standard groups select box for selecting a group id for a form.
  #The +parameter_name+ argument will be the name of the parameter 
  #when the form is submitted. and the +select_tag_options+ hash will be sent
  #directly as options to the +select_tag+ helper method called to create the element.
  #The +options+ hash can contain contain either or both of the following:
  #[selector] used for default selection. This can be a Group object, a group id (String or Fixnum),
  #           or any model that has a group_id attribute.
  #[groups] the array of Group objects used to build the select box. Defaults to +current_user.available_groups+.
  def group_select(parameter_name = "group_id", options = {}, select_tag_options = {} )
    options  = { :selector => options } unless options.is_a?(Hash)
    selector = options[:selector]
    groups    = options[:groups] || current_user.available_groups
  
    if selector.respond_to?(:group_id)
      selected = selector.group_id.to_s
    elsif selector.is_a?(Group)
      selected = selector.id.to_s
    else
      selected = selector.to_s
    end
    
    grouped_by_classes = groups.group_by { |gr| gr.class.to_s.underscore.humanize }

    category_grouped = {}
    grouped_by_classes.each do |entry|
      group_category_name = entry.first
      group_category_name.sub!(/ group/," project")
      group_pairs         = entry.last.sort_by(&:name).map{|elem| [elem.name, elem.id.to_s]}
      category_grouped[group_category_name] = group_pairs
    end

    ordered_category_grouped = []
    [ "Work project", "Site project", "User project", "System project", "Invisible project" ].each do |proj|
       ordered_category_grouped << [ proj , category_grouped.delete(proj) ] if category_grouped[proj]
    end

    grouped_options = grouped_options_for_select ordered_category_grouped, selected || current_user.own_group.id.to_s

    blank_label = select_tag_options.delete(:include_blank)
    if blank_label
      blank_label = "" if blank_label == true
      grouped_options = "<option value=\"\">#{blank_label}</option>" + grouped_options
    end
    
    select_tag parameter_name, grouped_options, select_tag_options
  end
  
  #Create a standard data provider select box for selecting a data provider id for a form.
  #The +parameter_name+ argument will be the name of the parameter 
  #when the form is submitted. and the +select_tag_options+ hash will be sent
  #directly as options to the +select_tag+ helper method called to create the element.
  #The +options+ hash can contain contain either or both of the following:
  #[selector] used for default selection. This can be a DataProvider object, a data provider id (String or Fixnum),
  #           or any model that has a data_provider_id attribute.
  #[data_providers] the array of DataProvider objects used to build the select box. Defaults to all data providers
  #                 accessible by this user.
  def data_provider_select(parameter_name = "data_provider_id", options = {}, select_tag_options = {} )
    options  = { :selector => options } unless options.is_a?(Hash)
    selector = options[:selector]
    if selector.nil? && current_user.user_preference
      selector = current_user.user_preference.data_provider_id
    end
    data_providers = options[:data_providers] || DataProvider.find_all_accessible_by_user(current_user)
  
    if selector.respond_to?(:data_provider_id)
      selected = selector.data_provider_id.to_s
    elsif selector.is_a?(DataProvider)
      selected = selector.id.to_s
    else
      selected = selector.to_s
    end 
    
    grouped_dps     = data_providers.group_by{ |dp| dp.is_browsable? ? "User Storage" : "CBRAIN Official Storage" }
    grouped_options = grouped_options_for_select(grouped_dps.collect {|pair| [pair.first, pair.last.sort_by(&:name).map{|dp| [dp.name, dp.id.to_s]}] }, 
                      selected)
    blank_label = select_tag_options.delete(:include_blank)
    if blank_label
      blank_label = "" if blank_label == true
      grouped_options = "<option value=\"\">#{blank_label}</option>" + grouped_options
    end
    
    select_tag parameter_name, grouped_options, select_tag_options
  end
  
  #Create a standard bourreau select box for selecting a bourreau id for a form.
  #The +parameter_name+ argument will be the name of the parameter 
  #when the form is submitted. and the +select_tag_options+ hash will be sent
  #directly as options to the +select_tag+ helper method called to create the element.
  #The +options+ hash can contain contain either or both of the following:
  #[selector] used for default selection. This can be a Bourreau object, a Boureau id (String or Fixnum),
  #           or any model that has a bourreau_id attribute.
  #[bourreaux] the array of Bourreau objects used to build the select box. Defaults to all bourreaux
  #            accessible by this user.
  def bourreau_select(parameter_name = "bourreau_id", options = {}, select_tag_options = {} )
    options  = { :selector => options } unless options.is_a?(Hash)
    selector = options[:selector]
    if selector.nil? && current_user.user_preference
      selector = current_user.user_preference.bourreau_id
    end
    bourreaux = options[:bourreaux] || Bourreau.find_all_accessible_by_user(current_user)
  
    if selector.respond_to?(:bourreau_id)
      selected = selector.bourreau_id.to_s
    elsif selector.is_a?(Bourreau)
      selected = selector.id.to_s
    else
      selected = selector.to_s
    end 
    if bourreaux && bourreaux.size > 0
      options = options_for_select(bourreaux.sort_by(&:name).map {|b| [b.name, b.id.to_s]}, 
                        selected)
      blank_label = select_tag_options.delete(:include_blank)
      if blank_label
        blank_label = "" if blank_label == true
        options = "<option value=\"\">#{blank_label}</option>" + options
      end
      
      select_tag parameter_name, options, select_tag_options
    else
      "<strong style=\"color:red\">No Execution Servers Available</strong>"
    end
  end

end

