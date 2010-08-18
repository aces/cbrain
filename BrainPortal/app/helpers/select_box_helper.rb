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
  #The <pre>parameter_name</pre> argument will be the name of the parameter 
  #when the form is submitted. and the <pre>select_tag_options</pre> hash will be sent
  #directly as options to the <pre>select_tag</pre> helper method called to create the element.
  #The +options+ hash can contain contain either or both of the following:
  #[selector] used for default selection. This can be a User object, a user id (String or Fixnum),
  #           or any model that has a user_id attribute.
  #[users] the array of User objects used to build the select box. Defaults to <pre>current_user.available_users</pre>.
  def user_select(parameter_name = "user_id", options = {}, select_tag_options = {} )
    options  = { :selector => options } unless options.is_a?(Hash)
    selector = options[:selector]
    users    = options[:user] || current_user.available_users
  
    if selector.respond_to?(:user_id)
      sel = selector.user_id.to_s
    elsif selector.is_a?(User)
      sel = selector.id.to_s
    else
      sel = selector.to_s
    end 
    render :partial => 'layouts/user_select', :locals  => { :parameter_name  => parameter_name, :selected  => sel, :users  => users, :select_tag_options => select_tag_options}
  end
  
  #Create a standard groups select box for selecting a group id for a form.
  #The <pre>parameter_name</pre> argument will be the name of the parameter 
  #when the form is submitted. and the <pre>select_tag_options</pre> hash will be sent
  #directly as options to the <pre>select_tag</pre> helper method called to create the element.
  #The +options+ hash can contain contain either or both of the following:
  #[selector] used for default selection. This can be a Group object, a group id (String or Fixnum),
  #           or any model that has a group_id attribute.
  #[groups] the array of Group objects used to build the select box. Defaults to <pre>current_user.available_groups</pre>.
  def group_select(parameter_name = "group_id", options = {}, select_tag_options = {} )
    options  = { :selector => options } unless options.is_a?(Hash)
    selector = options[:selector]
    groups    = options[:groups] || current_user.available_groups
  
    if selector.respond_to?(:group_id)
      sel = selector.group_id.to_s
    elsif selector.is_a?(Group)
      sel = selector.id.to_s
    else
      sel = selector.to_s
    end
  
    render :partial => 'layouts/group_select', :locals  => { :parameter_name  => parameter_name, :selected  => sel, :groups  => groups, :select_tag_options => select_tag_options}
  end
  
  #Create a standard data provider select box for selecting a data provider id for a form.
  #The <pre>parameter_name</pre> argument will be the name of the parameter 
  #when the form is submitted. and the <pre>select_tag_options</pre> hash will be sent
  #directly as options to the <pre>select_tag</pre> helper method called to create the element.
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
      sel = selector.data_provider_id.to_s
    elsif selector.is_a?(DataProvider)
      sel = selector.id.to_s
    else
      sel = selector.to_s
    end 
    render :partial => 'layouts/data_provider_select', :locals  => { :parameter_name  => parameter_name, :selected  => sel, :data_providers  => data_providers, :select_tag_options => select_tag_options}
  end
  
  #Create a standard bourreau select box for selecting a bourreau id for a form.
  #The <pre>parameter_name</pre> argument will be the name of the parameter 
  #when the form is submitted. and the <pre>select_tag_options</pre> hash will be sent
  #directly as options to the <pre>select_tag</pre> helper method called to create the element.
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
      sel = selector.bourreau_id.to_s
    elsif selector.is_a?(Bourreau)
      sel = selector.id.to_s
    else
      sel = selector.to_s
    end 
    render :partial => 'layouts/bourreau_select', :locals  => { :parameter_name  => parameter_name, :selected  => sel, :bourreaux  => bourreaux, :select_tag_options => select_tag_options}
  end

end

