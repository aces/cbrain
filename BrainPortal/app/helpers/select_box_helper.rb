
#
# CBRAIN Project
#
# Copyright (C) 2008-2012
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.  
#

#Helper methods for resource select boxes.
module SelectBoxHelper

  Revision_info=CbrainFileRevision[__FILE__]
  
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
    users    = options[:users] || current_user.available_users
  
    if selector.respond_to?(:user_id)
      selected = selector.user_id.to_s
    elsif selector.is_a?(User)
      selected = selector.id.to_s
    elsif selector.is_a?(Array) # for 'multiple' select
      selected = selector
    else
      selected = selector.to_s
    end
    grouped_options = options_for_select(users.sort_by(&:login).collect { |u| [ "#{u.login} (#{u.full_name})", u.id.to_s ] }, selected || current_user.id.to_s)
    blank_label = select_tag_options.delete(:include_blank)
    if blank_label
      blank_label = "" if blank_label == true
      grouped_options = "<option value=\"\">#{h(blank_label)}</option>".html_safe + grouped_options
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
    selector = options[:selector] || current_project
    groups   = options[:groups]   || current_user.available_groups
  
    if selector.respond_to?(:group_id)
      selected = selector.group_id.to_s
    elsif selector.is_a?(Group)
      selected = selector.id.to_s
    elsif selector.is_a?(Array) # for 'multiple' select
      selected = selector
    else
      selected = selector.to_s
    end
    
    group_labels = {}
    WorkGroup.prepare_pretty_category_names(groups, current_user)
    group_labels.merge!(UserGroup.prepare_pretty_labels(groups))
    group_labels.merge!(SiteGroup.prepare_pretty_labels(groups))
    grouped_by_classes = groups.group_by { |gr| gr.pretty_category_name(current_user) }

    category_grouped = {}
    grouped_by_classes.each do |entry|
      group_category_name = entry.first.sub(/Project/,"Projects")
      group_pairs         = entry.last.sort_by(&:name).map do |group|
        label = group_labels[group.id] || group.name
        [label, group.id.to_s]
      end
      category_grouped[group_category_name] = group_pairs
    end

    ordered_category_grouped = []
    category_grouped.keys.each do |proj|
       next unless proj =~ /Personal Work Projects of/
       ordered_category_grouped << [ proj, category_grouped.delete(proj) ]
    end
    [ "My Work Projects", "Shared Work Projects", "Site Projects", "User Projects", "System Projects", "Invisible Projects" ].each do |proj|
       ordered_category_grouped << [ proj, category_grouped.delete(proj) ] if category_grouped[proj]
    end
    category_grouped.keys.each do |proj| # handle what remains ?
       ordered_category_grouped << [ "X-#{proj}" , category_grouped.delete(proj) ]
    end

    grouped_options = grouped_options_for_select ordered_category_grouped, selected || current_user.own_group.id.to_s

    blank_label = select_tag_options.delete(:include_blank)
    if blank_label
      blank_label = "" if blank_label == true
      grouped_options = "<option value=\"\">#{h(blank_label)}</option>".html_safe + grouped_options
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
    data_providers = options[:data_providers] || DataProvider.find_all_accessible_by_user(current_user).all
  
    if selector.respond_to?(:data_provider_id)
      selected = selector.data_provider_id.to_s
    elsif selector.is_a?(DataProvider)
      selected = selector.id.to_s
    elsif selector.is_a?(Array) # for 'multiple' select
      selected = selector
    else
      selected = selector.to_s
    end 
    
    grouped_dps     = data_providers.group_by{ |dp| dp.is_browsable? ? "User Storage" : "CBRAIN Official Storage" }
    grouped_oplists = []
    [ "CBRAIN Official Storage", "User Storage" ].collect do |group_title|
       next unless dps_in_group = grouped_dps[group_title]
       dps_in_group = dps_in_group.sort_by(&:name)
       options_dps  = dps_in_group.map do |dp|
         opt_pair = [ dp.name, dp.id.to_s ]
         if (! dp.online?) && (! options[:offline_is_ok])
           opt_pair[0] += " (offline)"
           opt_pair << { :disabled => "true" }
         end
         opt_pair #  [ "DpName", "3" ]    or   [ "DpName", "3", { :disabled => "true" } ]
       end
       grouped_oplists << [ group_title, options_dps ]  # [ "GroupName", [  [ dp1, 1 ], [dp2, 2] ] ]
    end
    grouped_options = grouped_options_for_select(grouped_oplists.compact, selected)

    blank_label = select_tag_options.delete(:include_blank)
    if blank_label
      blank_label = "" if blank_label == true
      grouped_options = "<option value=\"\">#{h(blank_label)}</option>".html_safe + grouped_options
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
    bourreaux = options[:bourreaux] || Bourreau.find_all_accessible_by_user(current_user).all
  
    if selector.respond_to?(:bourreau_id)
      selected = selector.bourreau_id.to_s
    elsif selector.is_a?(Bourreau)
      selected = selector.id.to_s
    elsif selector.is_a?(Array) # for 'multiple' select
      selected = selector
    else
      selected = selector.to_s
    end 

    return "<strong style=\"color:red\">No Execution Servers Available</strong>".html_safe if bourreaux.blank?

    bourreaux_pairs = bourreaux.sort_by(&:name).map do |b|
       opt_pair = [ b.name, b.id.to_s ]
       if (! b.online?) && (! options[:offline_is_ok])
         opt_pair[0] += " (offline)"
         opt_pair << { :disabled => "true" }
       end
       opt_pair #  [ "BoName", "3" ]    or   [ "BoName", "3", { :disabled => "true" } ]
    end
    options = options_for_select(bourreaux_pairs, selected)
    blank_label = select_tag_options.delete(:include_blank)
    if blank_label
      blank_label = "" if blank_label == true
      options = "<option value=\"\">#{h(blank_label)}</option>".html_safe + options
    end
    
    select_tag parameter_name, options, select_tag_options
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
    elsif selector.is_a?(Array) # for 'multiple' select
      selected = selector
    else
      selected = selector.to_s
    end

    tool_configs  = Array(options[:tool_configs] || ToolConfig.find_all_accessible_by_user(current_user).all)

    tool_config_options = []   # [ [ grouplabel, [ [pair], [pair] ] ], [ grouplabel, [ [pair], [pair] ] ] ]

    bourreaux_by_ids = Bourreau.where(:id => tool_configs.map(&:bourreau_id).uniq.compact).all.index_by &:id
    tools_by_ids     = Tool.where(    :id => tool_configs.map(&:tool_id).uniq.compact).all.index_by &:id

    # Globals for Execution Servers
    bourreau_globals = tool_configs.select { |tc| tc.tool_id.blank? }
    if bourreau_globals.size > 0
      pairlist = []
      sorted_tcs = bourreau_globals.sort do |tc1,tc2|
        bourreaux_by_ids[tc1.bourreau_id].name <=> bourreaux_by_ids[tc2.bourreau_id].name
      end
      sorted_tcs.each do |tc|
        pairlist << [ bourreaux_by_ids[tc.bourreau_id].name, tc.id.to_s ]
      end
      tool_config_options << [ "For Execution Servers (any Tool):", pairlist ]
    end

    # Globals for Tools
    tool_globals = tool_configs.select { |tc| tc.bourreau_id.blank? }
    if tool_globals.size > 0
      pairlist = []
      sorted_tcs = tool_globals.sort do |tc1,tc2|
        tools_by_ids[tc1.tool_id].name <=> tools_by_ids[tc2.tool_id].name
      end
      sorted_tcs.each do |tc|
        pairlist << [ tools_by_ids[tc.tool_id].name, tc.id.to_s ]
      end
      tool_config_options << [ "For Tools (any Execution Server):", pairlist ]
    end

    # Other Tool Configs with both Tool and Bourreau in it
    spec_tool_configs  = tool_configs.select { |tc| tc.tool_id.present? && tc.bourreau_id.present? }
    same_tool          = tool_configs.all?   { |tc| tc.tool_id     == tool_configs[0].tool_id }
    same_bourreau      = tool_configs.all?   { |tc| tc.bourreau_id == tool_configs[0].bourreau_id }

    tcs_by_bourreau_id   = spec_tool_configs.group_by { |tc| tc.bourreau_id }
    ordered_bourreau_ids = tcs_by_bourreau_id.keys.sort { |bid1,bid2| bourreaux_by_ids[bid1].name <=> bourreaux_by_ids[bid2].name }
    ordered_bourreau_ids.each do |bid|
      bourreau              = bourreaux_by_ids[bid]
      bourreau_tool_configs = tcs_by_bourreau_id[bid]
      tcs_by_tool_id        = bourreau_tool_configs.group_by { |tc| tc.tool_id }
      ordered_tool_ids      = tcs_by_tool_id.keys.sort { |tid1,tid2| tools_by_ids[tid1].name <=> tools_by_ids[tid2].name }
      ordered_tool_ids.each do |tid|
        tool = tools_by_ids[tid]
        tool_tool_configs = tcs_by_tool_id[tid].sort do |tc1,tc2|
          tc1.created_at <=> tc2.created_at # creation date usually sorts by 'most recent version'
        end
        pairlist = []
        tool_tool_configs.each do |tc|
          desc = tc.short_description
          pairlist << [ desc, tc.id.to_s ]
        end
        if same_tool && (! same_bourreau || ordered_bourreau_ids.size == 1)
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
      grouped_options = "<option value=\"\">#{h(blank_label)}</option>".html_safe + grouped_options
    end
    
    select_tag parameter_name, grouped_options, select_tag_options
  end

#------------------
  #Create a standard task by status select box for selecting a task status for a form.
  #The +parameter_name+ argument will be the name of the parameter 
  #when the form is submitted and the +select_tag_options+ hash will be sent
  #directly as options to the +select_tag+ helper method called to create the element.
  #The +options+ hash can contain either or both of the following:
  #[selector] used for default selection. This can be a task status.
  #[task_status] the array of task status used to build the select box. Default CbrainTask::ALL_STATUS.
  def task_status_select(parameter_name = "data[status]", options = {}, select_tag_options = {} )
    options     = { :selector => options } unless options.is_a?(Hash)
    selected    = options[:selector]
    task_status = options[:task_status] || (CbrainTask::ALL_STATUS - ["Preset", "SitePreset", "Duplicated"])

    standard    = CbrainTask::RUNNING_STATUS + CbrainTask::COMPLETED_STATUS
    waiting     = CbrainTask::QUEUED_STATUS  - CbrainTask::RUNNING_STATUS
    failed      = CbrainTask::FAILED_STATUS
    restarting  = CbrainTask::RESTART_STATUS
    recovering  = CbrainTask::RECOVER_STATUS

    status_grouped = {}
    task_status.each do |status|
      if standard.include?(status)
        (status_grouped["Standard Cycle"] ||= []) << status
      elsif waiting.include?(status)
        (status_grouped["Waiting"]        ||= []) << status
      elsif failed.include?(status)
        (status_grouped["Failed"]         ||= []) << status
      elsif restarting.include?(status)
        (status_grouped["Restarting"]     ||= []) << status
      elsif recovering.include?(status)
        (status_grouped["Recovering"]     ||= []) << status 
      else
        (status_grouped["Other"]          ||= []) << status 
      end
    end

    grouped_by_category = []
    [ "Standard Cycle", "Waiting","Failed", "Restarting", "Recovering", "Unknown"].each do |category|
      next unless status_grouped[category]
      sorted_statuses = status_grouped[category].sort { |a,b| cmp_status_order(a,b) }
      grouped_by_category << [ category , sorted_statuses ]
    end

    grouped_options = grouped_options_for_select grouped_by_category, selected
    
    blank_label = select_tag_options.delete(:include_blank)
    if blank_label
      blank_label = "" if blank_label == true
      grouped_options = "<option value=\"\">#{h(blank_label)}</option>".html_safe + grouped_options
    end
    
    select_tag parameter_name, grouped_options, select_tag_options
  end

  #Create a standard userfiles type select box for selecting a userfile type for a form.
  #The +parameter_name+ argument will be the name of the parameter 
  #when the form is submitted and the +select_tag_options+ hash will be sent
  #directly as options to the +select_tag+ helper method called to create the element.
  #The +options+ hash can contain either or both of the following:
  #[selector] used for default selection. This can be a Userfile type.
  #[userfile_types] a list of Userfiles type used to build the select box.
  #[generate_descendants] a boolean if it's true take the descendant of classes in :userfile_types else only take 
  #the classes in :userfile_types
  #[:include_top] a boolean only used when :generate_descendants is true, if it's true
  #keep the top and the descendants, otherwise only takes the descendants.
  def userfile_type_select(parameter_name = "file_type", options = {}, select_tag_options = {} )
    options              = { :selector => options } unless options.is_a?(Hash)
    generate_descendants =  options.has_key?(:generate_descendants) ? options[:generate_descendants] : true
    userfile_types       = (options[:userfile_types] || ["SingleFile","FileCollection"]).collect!{|type| type.constantize}
    include_top          = options.has_key?(:include_top) ? options[:include_top] : true

    type_select(parameter_name, options.dup.merge({:types => userfile_types, :generate_descendants => generate_descendants, :include_top => include_top}), select_tag_options)
  end

  #Create a standard groups type select box for selecting a group type for a form.
  #The +parameter_name+ argument will be the name of the parameter 
  #when the form is submitted and the +select_tag_options+ hash will be sent
  #directly as options to the +select_tag+ helper method called to create the element.
  #The +options+ hash can contain either or both of the following:
  #[selector] used for default selection. This can be a Group type.
  #[group_types] a list of Groups type used to build the select box.
  #[generate_descendants] a boolean if it's true take the descendant of classes in :group_types else only take 
  #the classes in :group_types
  #[:include_top] a boolean only used when :generate_descendants is true, if it's true
  #keep the top and the descendants, otherwise only takes the descendants.
  def group_type_select(parameter_name = "group_type", options = {}, select_tag_options = {} )
    options              = { :selector => options } unless options.is_a?(Hash)
    generate_descendants =  options.has_key?(:generate_descendants) ? options[:generate_descendants] : true
    group_types          = (options[:group_types] || ["SystemGroup", "WorkGroup"]).collect!{|type| type.constantize}
    include_top          = options.has_key?(:include_top) ? options[:include_top] : true

    type_select(parameter_name, options.dup.merge({:types => group_types, :generate_descendants => generate_descendants, :include_top => include_top}), select_tag_options)
  end

  #Create a standard tasks type select box for selecting a task type for a form.
  #The +parameter_name+ argument will be the name of the parameter 
  #when the form is submitted and the +select_tag_options+ hash will be sent
  #directly as options to the +select_tag+ helper method called to create the element.
  #The +options+ hash can contain either or both of the following:
  #[selector] used for default selection. This can be a Task type.
  #[task_types] a list of Tasks type used to build the select box.
  #[generate_descendants] a boolean if it's true take the descendant of classes in :task_types else only take 
  #the classes in :task_types
  #[:include_top] a boolean only used when :generate_descendants is true, if it's true
  #keep the top and the descendants, otherwise only takes the descendants.
  def task_type_select(parameter_name = "task_type", options = {}, select_tag_options = {} )
    options              = { :selector => options } unless options.is_a?(Hash)
    generate_descendants =  options.has_key?(:generate_descendants) ? options[:generate_descendants] : true
    task_types           = (options[:task_types] || ["PortalTask"]).collect!{|type| type.constantize}
    include_top          = options.has_key?(:include_top) ? options[:include_top] : false

    type_select(parameter_name, options.dup.merge({:types => task_types, :generate_descendants => generate_descendants, :include_top => include_top}), select_tag_options)
  end


  #Create a standard types select box for selecting a types type for a form.
  #The +parameter_name+ argument will be the name of the parameter 
  #when the form is submitted and the +select_tag_options+ hash will be sent
  #directly as options to the +select_tag+ helper method called to create the element.
  #The +options+ hash can contain either or both of the following:
  #[selector] used for default selection. This can be a type present in types.
  #[types] a list of types used to build the select box.
  #[generate_descendants] a boolean if it's true take the descendant of classes in :types else only take 
  #the classes in :types
  #[:include_top] a boolean only used when :generate_descendants is true, if it's true
  #keep the top and the descendants, otherwise only takes the descendants.
  def type_select(parameter_name = "type", options = {}, select_tag_options = {} )
    options              = { :selector => options } unless options.is_a?(Hash)
    generate_descendants = options[:generate_descendants]
    types                = options[:types]
    include_top          = options[:include_top]
    blank_label          = select_tag_options.delete(:include_blank)
    blank_label          = "" if blank_label == true
    selected             = options[:selector]
    
    grouped_options      = ""
    # Create a hierarchical select box with all the type
    types.each do |type|
      if generate_descendants
        grouped_options += hierarchical_type_options_for_select(type, selected, :include_top => include_top)
      else
        grouped_options += options_for_select [[type.pretty_type, type.name]], selected
      end
    end

    # Add blank label 
    if blank_label
      blank_label = "" if blank_label == true
      grouped_options = "<option value=\"\">#{h(blank_label)}</option>" + grouped_options
    end
    
    select_tag parameter_name, grouped_options.html_safe, select_tag_options
  end

  private

  #Create an options_for_select box.
  #The +top+ parameter is the top level type, one with which we start.
  #The +selected+ parameter indicate which element need to be selected
  #[:include_top] indicate if top is or is not keep in final options_for_select
  def hierarchical_type_options_for_select(top, selected, options = {})
    include_top = options.has_key?(:include_top) ? options[:include_top] : false
    klass_lev   = { top => include_top ? 0 : -1 }
    queue       = [ top ]
    final       = []

    while ! queue.empty? do
       first = queue.shift
       lev   = klass_lev[first]
       desc  = first.direct_descendants.sort { |a,b| a.name <=> b.name }
       desc.each { |d| klass_lev[d] = lev + 1 }
       queue = desc + queue
       final << first unless !include_top && first == top
    end

    ordered_type_grouped = []
    final.each do |k|
       lev = klass_lev[k]
       ordered_type_grouped << ["#{("&nbsp;&nbsp;" * lev)}#{k.pretty_type}".html_safe,k.name]
    end
    
    options_for_select ordered_type_grouped, selected
  end
  
end


  

