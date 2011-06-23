#Helper methods for resource select boxes.
module SelectBoxHelper

  Revision_info="$Id$"
  
  #################################################################################
  # Selector Helpers
  #################################################################################
  
  # Create options for a select box with optgroups.
  def grouped_options_for_select(grouped_options, selected_key = nil, prompt = nil)
    body = ''
    body << content_tag(:option, prompt, :value => "") if prompt
  
    grouped_options = grouped_options.sort if grouped_options.is_a?(Hash)
  
    grouped_options.each do |group|
      body << content_tag(:optgroup, options_for_select(group[1], selected_key), :label => group[0])
    end
  
    body.html_safe
  end
  
  #Create a standard user select box for selecting a user id for a form.
  #The +parameter_name+ argument will be the name of the parameter 
  #when the form is submitted and the +select_tag_options+ hash will be sent
  #directly as options to the +select_tag+ helper method called to create the element.
  #The +options+ hash can contain either or both of the following:
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
    grouped_options = options_for_select(users.sort_by(&:login).collect { |u| [ "#{u.login} (#{u.full_name})", u.id.to_s ] }, selected || current_user.id.to_s)
    blank_label = select_tag_options.delete(:include_blank)
    if blank_label
      blank_label = "" if blank_label == true
      grouped_options = "<option value=\"\">#{blank_label}</option>" + grouped_options
    end
    
    select_tag parameter_name, grouped_options, select_tag_options
  end
  
  #Create a standard groups select box for selecting a group id for a form.
  #The +parameter_name+ argument will be the name of the parameter 
  #when the form is submitted and the +select_tag_options+ hash will be sent
  #directly as options to the +select_tag+ helper method called to create the element.
  #The +options+ hash can contain either or both of the following:
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
    
    #grouped_by_classes = groups.group_by { |gr| gr.class.to_s.underscore.humanize }
    grouped_by_classes = groups.group_by { |gr| gr.pretty_category_name(current_user) }

    category_grouped = {}
    grouped_by_classes.each do |entry|
      group_category_name = entry.first
      group_pairs         = entry.last.sort_by(&:name).map do |group|
        label = group.name
        if group.is_a?(UserGroup)
          group_user_full = group.users[0].full_name rescue nil
          #label += " " * (12 - label.size) if label.size < 12
          label += " (#{group_user_full})" if ! group_user_full.blank?
        elsif group.is_a?(SiteGroup)
          group_site_header = split_description(group.site.description)[0] rescue nil
          label += " (#{crop_text_to(20,group_site_header)})" if ! group_site_header.blank?
        end
        [label, group.id.to_s]
      end
      category_grouped[group_category_name] = group_pairs
    end

    ordered_category_grouped = []
    category_grouped.keys.each do |proj|
       next unless proj =~ /Personal Work Project of/
       ordered_category_grouped << [ proj , category_grouped.delete(proj) ]
    end
    [ "My Work Project", "Shared Work Project", "Site Project", "User Project", "System Project", "Invisible Project" ].each do |proj|
       ordered_category_grouped << [ proj , category_grouped.delete(proj) ] if category_grouped[proj]
    end
    category_grouped.keys.each do |proj| # handle what remains ?
       ordered_category_grouped << [ "X-#{proj}" , category_grouped.delete(proj) ]
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
  #when the form is submitted and the +select_tag_options+ hash will be sent
  #directly as options to the +select_tag+ helper method called to create the element.
  #The +options+ hash can contain either or both of the following:
  #[selector] used for default selection. This can be a DataProvider object, a data provider id (String or Fixnum),
  #           or any model that has a data_provider_id attribute.
  #[data_providers] the array of DataProvider objects used to build the select box. Defaults to all data providers
  #                 accessible by the current_user.
  def data_provider_select(parameter_name = "data_provider_id", options = {}, select_tag_options = {} )
    options  = { :selector => options } unless options.is_a?(Hash)
    selector = options[:selector]
    if selector.nil?
      selector = current_user.meta["pref_data_provider_id"]
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
      grouped_options = "<option value=\"\">#{blank_label}</option>".html_safe + grouped_options
    end
    
    select_tag parameter_name, grouped_options, select_tag_options
  end
  
  #Create a standard bourreau select box for selecting a bourreau id for a form.
  #The +parameter_name+ argument will be the name of the parameter 
  #when the form is submitted and the +select_tag_options+ hash will be sent
  #directly as options to the +select_tag+ helper method called to create the element.
  #The +options+ hash can contain either or both of the following:
  #[selector] used for default selection. This can be a Bourreau object, a Boureau id (String or Fixnum),
  #           or any model that has a bourreau_id attribute.
  #[bourreaux] the array of Bourreau objects used to build the select box. Defaults to all bourreaux
  #            accessible by the current_user.
  def bourreau_select(parameter_name = "bourreau_id", options = {}, select_tag_options = {} )
    options  = { :selector => options } unless options.is_a?(Hash)
    selector = options[:selector]
    if selector.nil?
      selector = current_user.meta["pref_bourreau_id"]
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
      "<strong style=\"color:red\">No Execution Servers Available</strong>".html_safe
    end
  end

  #Create a standard tool config select box for selecting a tool config in a form.
  #The +parameter_name+ argument will be the name of the parameter 
  #when the form is submitted and the +select_tag_options+ hash will be sent
  #directly as options to the +select_tag+ helper method called to create the element.
  #
  #The +options+ hash can contain either or both of the following:
  #
  #[selector] used for default selection. This can be a ToolConfig object, a ToolConfig id (String or Fixnum),
  #           or any model that has a tool_config attribute.
  #[tool_configs] the array of ToolConfig objects used to build the select box. Defaults to all tool configs
  #                 accessible by the current_user.
  #
  #The selection box will partition the ToolConfig objects by 'categories', where there
  #are three such categories:
  #
  #- ToolConfigs for specific Bourreaux (and any Tools)
  #- ToolConfigs for specific Tools (and any Bourreaux)
  #- ToolConfigs for specific Tools on specific Bourreaux
  #
  def tool_config_select(parameter_name = 'tool_config_id', options = {}, select_tag_options = {})
    options       = { :selector => options } unless options.is_a?(Hash)
    selector      = options[:selector]
    if selector.respond_to?(:tool_config_id)
      selected = selector.tool_config_id.to_s
    elsif selector.is_a?(ToolConfig)
      selected = selector.id.to_s
    else
      selected = selector.to_s
    end

    tool_configs  = options[:tool_configs] || ToolConfig.all.select { |tc| tc.can_be_accessed_by?(current_user) }

    tool_config_options = []   # [ [ grouplabel, [ [pair], [pair] ] ], [ grouplabel, [ [pair], [pair] ] ] ]

    # Globals for Execution Servers
    bourreau_globals = tool_configs.select { |tc| tc.tool_id.blank? }
    if bourreau_globals.size > 0
      pairlist = []
      bourreau_globals.sort! { |tc1,tc2| tc1.bourreau.name <=> tc2.bourreau.name }.each do |tc|
        pairlist << [ tc.bourreau.name, tc.id.to_s ]
      end
      tool_config_options << [ "For Execution Servers (any Tool):", pairlist ]
    end

    # Globals for Tools
    tool_globals = tool_configs.select { |tc| tc.bourreau_id.blank? }
    if tool_globals.size > 0
      pairlist = []
      tool_globals.sort { |tc1,tc2| tc1.tool.name <=> tc2.tool.name }.each do |tc|
        pairlist << [ tc.tool.name, tc.id.to_s ]
      end
      tool_config_options << [ "For Tools (any Execution Server):", pairlist ]
    end

    # Other Tool Configs with both Tool and Bourreau in it
    spec_tool_configs  = tool_configs - bourreau_globals - tool_globals
    same_tool          = tool_configs.all? { |tc| tc.tool_id     == tool_configs[0].tool_id }
    same_bourreau      = tool_configs.all? { |tc| tc.bourreau_id == tool_configs[0].bourreau_id }

    by_bourreaux = spec_tool_configs.group_by { |tc| tc.bourreau }
    ordered_bourreaux = by_bourreaux.keys.sort { |bourreau1,bourreau2| bourreau1.name <=> bourreau2.name }
    ordered_bourreaux.each do |bourreau|
      bourreau_tool_configs = by_bourreaux[bourreau]
      by_tool               = bourreau_tool_configs.group_by { |tc| tc.tool }
      ordered_tools         = by_tool.keys.sort { |tool1,tool2| tool1.name <=> tool2.name }
      ordered_tools.each do |tool|
        tool_tool_configs = by_tool[tool].sort do |tc1,tc2|
          cmp = (tc1.tool.name <=> tc2.tool.name)
          cmp != 0 ? cmp : (tc1.created_at <=> tc2.created_at)
        end
        pairlist = []
        tool_tool_configs.each do |tc|
          desc = tc.short_description
          pairlist << [ desc, tc.id.to_s ]
        end
        if same_tool && (! same_bourreau || ordered_bourreaux.size == 1)
          label = "On #{bourreau.name}:"
        elsif same_bourreau && ! same_tool
          label = "For tool #{tool.name}:"
        else
          label = "On #{bourreau.name} for tool #{tool.name}:"
        end
        tool_config_options << [ label , pairlist ]
      end
    end

    # Create the selection tag
    grouped_options = grouped_options_for_select(tool_config_options, selected)

    blank_label = select_tag_options.delete(:include_blank)
    if blank_label
      blank_label = "" if blank_label == true
      grouped_options = "<option value=\"\">#{blank_label}</option>" + grouped_options
    end
    
    select_tag parameter_name, grouped_options, select_tag_options
  end

end

