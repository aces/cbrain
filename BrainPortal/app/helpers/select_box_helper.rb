
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

# Helper methods for resource select boxes.
module SelectBoxHelper

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Create a standard user select box for selecting a user id for a form.
  # The +parameter_name+ argument will be the name of the parameter
  # when the form is submitted and the +select_tag_options+ hash will be sent
  # directly as options to the +select_tag+ helper method called to create the element.
  # The +options+ hash can contain either or both of the following:
  # [selector] used for default selection. This can be a User object, a user id (String or Integer),
  #            or any model that has a user_id attribute.
  # [users] the array of User objects used to build the select box. Defaults to +current_user.available_users+.
  def user_select(parameter_name = "user_id", options = {}, select_tag_options = {} )
    options  = { :selector => options } unless options.is_a?(Hash)
    selector = options[:selector]
    users    = options[:users] || current_user.available_users
    users    = users.all.to_a if users.is_a?(ActiveRecord::Relation)

    if selector.respond_to?(:user_id)
      selected = selector.user_id.to_s
    elsif selector.is_a?(User)
      selected = selector.id.to_s
    elsif selector.is_a?(Array) # for 'multiple' select
      selected = selector
    else
      selected = selector.to_s
    end

    # Final HTML rendering of the options for select
    user_by_lock_status = regroup_users_by_lock_status(users)
    grouped_options     = grouped_options_for_select user_by_lock_status, selected
    blank_label         = select_tag_options.delete(:include_blank) || options[:include_blank]
    if blank_label
      blank_label = "" if blank_label == true
      grouped_options = "<option value=\"\">#{h(blank_label)}</option>".html_safe + grouped_options
    end

    select_tag parameter_name, grouped_options, select_tag_options
  end

  # Create a standard site select box for selecting a site id for a form.
  # The +parameter_name+ argument will be the name of the parameter
  # when the form is submitted and the +select_tag_options+ hash will be sent
  # directly as options to the +select_tag+ helper method called to create the element.
  # The +options+ hash can contain either or both of the following:
  # [selector] used for default selection. This can be a Site object, a site id (String or Integer),
  #            or any model that has a site_id attribute.
  # [sites] the array of Site objects used to build the select box. Defaults to +Site.order(:name).all+.
  # +options+ need not be hash, the default selected item can be passed as an argument.
  # When calling site_select, set the :prompt option in select_tag_options hash, to the text you want
  # displayed when no option is selected
  def site_select(parameter_name = "site", options = {}, select_tag_options = {} )
    options  = { :selector => options } unless options.is_a?(Hash)
    sites = options[:sites] || Site.order(:name)
    sites = sites.all.to_a if sites.is_a?(ActiveRecord::Relation)
    selector = options[:selector]

    if selector.respond_to?(:site_id)
      selected = selector.site_id.to_s
    elsif selector.is_a?(Site)
      selected = selector.id.to_s
    else
      selected = selector.to_s
    end

    site_options = sites.map{ |s| [s.name, s.id]}

    select_tag parameter_name, options_for_select(site_options, selected), select_tag_options
  end




  # Create a standard groups select box for selecting a group id for a form.
  # The +parameter_name+ argument will be the name of the parameter
  # when the form is submitted and the +select_tag_options+ hash will be sent
  # directly as options to the +select_tag+ helper method called to create the element.
  # The +options+ hash can contain either or both of the following:
  # [selector] used for default selection. This can be a Group object, a group id (String or Integer),
  #            or any model that has a group_id attribute.
  # [groups] the array of Group objects used to build the select box. Defaults to +current_user.assignable_groups+.
  def group_select(parameter_name = "group_id", options = {}, select_tag_options = {} )
    options  = { :selector => options } unless options.is_a?(Hash)
    selector = options.has_key?(:selector) ? (options[:selector].presence || "") : current_project
    groups   = options.has_key?(:groups)   ? (options[:groups]            || []) : current_user.assignable_groups
    groups   = groups.all.to_a if groups.is_a?(ActiveRecord::Relation)

    if selector.respond_to?(:group_id)
      selected = selector.group_id.to_s
    elsif selector.is_a?(Group)
      selected = selector.id.to_s
    elsif selector.is_a?(Array) # for 'multiple' select
      selected = selector
    else
      selected = selector.to_s
    end

    # Optimize the labels for UserGroups and SiteGroups, by extracting in a hash
    group_labels = {}
    group_labels.merge!(UserGroup.prepare_pretty_labels(groups))
    group_labels.merge!(SiteGroup.prepare_pretty_labels(groups))

    # Optimize the category names for WorkGroup (the names will be cached in each group object)
    WorkGroup.prepare_pretty_category_names(groups, current_user)

    # Split all groups into sublists by category name
    grouped_by_categories = groups.group_by { |gr| gr.pretty_category_name(current_user) }

    # Prepare the categories, each getting a list of pairs [ [label, gid], [label, gid] ]
    category_grouped_pairs = {}
    grouped_by_categories.each do |entry|
      group_category_name = entry.first.sub(/Project/,"Projects")
      group_pairs         = entry.last.sort_by(&:name).map do |group|
        label = group_labels[group.id] || group.name
        [label, group.id.to_s]
      end
      category_grouped_pairs[group_category_name] = group_pairs
    end

    # Order the categories and their list of pairs... (4 steps)
    ordered_category_grouped = []

    # Step 1: My Work Projects first
    ordered_category_grouped << [ "My Work Projects", category_grouped_pairs.delete("My Work Projects") ] if category_grouped_pairs["My Work Projects"]

    # Step 2: All personal work projects first
    category_grouped_pairs.keys.select { |proj| proj =~ /Personal Work Projects/ }.sort.each do |proj|
       ordered_category_grouped << [ proj, category_grouped_pairs.delete(proj) ]
    end

    # Step 3: Other project categories, in that order
    [ "Shared Work Projects", "Empty Work Projects", "Site Projects", "User Projects", "System Projects", "Invisible Projects", "Everyone Projects", "Public Projects" ].each do |proj|
      ordered_category_grouped << [ proj, category_grouped_pairs.delete(proj) ] if category_grouped_pairs[proj]
    end

    # Step 4: Other mysterious categories ?!?
    category_grouped_pairs.keys.each do |proj|
      ordered_category_grouped << [ "X-#{proj}" , category_grouped_pairs.delete(proj) ]
    end

    # Final HTML rendering of the options for select
    grouped_options = grouped_options_for_select ordered_category_grouped, selected || current_user.own_group.id.to_s

    blank_label = select_tag_options.delete(:include_blank) || options[:include_blank]
    if blank_label
      blank_label = "" if blank_label == true
      grouped_options = "<option value=\"\">#{h(blank_label)}</option>".html_safe + grouped_options
    end

    select_tag parameter_name, grouped_options, select_tag_options
  end

  # Create a standard data provider select box for selecting a data provider id for a form.
  # The +parameter_name+ argument will be the name of the parameter
  # when the form is submitted and the +select_tag_options+ hash will be sent
  # directly as options to the +select_tag+ helper method called to create the element.
  # The +options+ hash can contain either or both of the following:
  # [selector] used for default selection. This can be a DataProvider object, a data provider id (String or Integer),
  #            or any model that has a data_provider_id attribute.
  # [data_providers] the array of DataProvider objects used to build the select box. Defaults to all data providers
  #                  accessible by the current_user.
  def data_provider_select(parameter_name = "data_provider_id", options = {}, select_tag_options = {} )
    options  = { :selector => options } unless options.is_a?(Hash)
    selector = options[:selector].presence
    if ! options.has_key?(:selector)
      selector = current_user.meta["pref_data_provider_id"]
    end
    data_providers = options[:data_providers] || DataProvider.find_all_accessible_by_user(current_user)
    data_providers = data_providers.all.to_a if data_providers.is_a?(ActiveRecord::Relation)

    if selector.respond_to?(:data_provider_id)
      selected = selector.data_provider_id.to_s
    elsif selector.is_a?(DataProvider)
      selected = selector.id.to_s
    elsif selector.is_a?(Array) # for 'multiple' select
      selected = selector
    else
      selected = selector.to_s
    end

    grouped_dps     = data_providers.group_by { |dp| dp.is_browsable? ? "User Storage" : "Service Storage" } # note: two lines below too
    grouped_oplists = []
    [ "Service Storage", "User Storage" ].collect do |group_title|
       next unless dps_in_group = grouped_dps[group_title]
       dps_in_group = dps_in_group.sort_by(&:name)
       options_dps  = dps_in_group.map do |dp|
         opt_pair = [ dp.name, dp.id.to_s ]
         if (! dp.online?) && (! options[:offline_is_ok])
           opt_pair[0] += " (offline)"
           opt_pair << { :disabled => "true" }
         end
         opt_pair #  [ "DpName", "3" ]    or   [ "DpName (offline)", "3", { :disabled => "true" } ]
       end
       grouped_oplists << [ group_title, options_dps ]  # [ "GroupName", [  [ dp1, 1 ], [dp2, 2] ] ]
    end
    grouped_options = grouped_options_for_select(grouped_oplists.compact, selected)

    blank_label = select_tag_options.delete(:include_blank) || options[:include_blank]
    if blank_label
      blank_label = "" if blank_label == true
      grouped_options = "<option value=\"\">#{h(blank_label)}</option>".html_safe + grouped_options
    end

    select_tag parameter_name, grouped_options, select_tag_options
  end

  # Create a standard bourreau select box for selecting a bourreau id for a form.
  # The +parameter_name+ argument will be the name of the parameter
  # when the form is submitted and the +select_tag_options+ hash will be sent
  # directly as options to the +select_tag+ helper method called to create the element.
  # The +options+ hash can contain either or both of the following:
  # [selector] used for default selection. This can be a Bourreau object, a Boureau id (String or Integer),
  #            or any model that has a bourreau_id attribute.
  # [bourreaux] the array of Bourreau objects used to build the select box. Defaults to all bourreaux
  #             accessible by the current_user.
  def bourreau_select(parameter_name = "bourreau_id", options = {}, select_tag_options = {} )
    options  = { :selector => options } unless options.is_a?(Hash)
    selector = options[:selector].presence
    if ! options.has_key?(:selector)
      selector = current_user.meta["pref_bourreau_id"].presence
    end
    bourreaux = options[:bourreaux] || Bourreau.find_all_accessible_by_user(current_user)
    bourreaux = bourreaux.all.to_a if bourreaux.is_a?(ActiveRecord::Relation)

    if selector.respond_to?(:bourreau_id)
      selected = selector.bourreau_id.to_s
    elsif selector.is_a?(Bourreau)
      selected = selector.id.to_s
    elsif selector.is_a?(Array) # for 'multiple' select
      selected = selector
    else
      selected = selector.to_s
    end

    return "<strong style=\"color:red\">No Execution Servers Available</strong>".html_safe if bourreaux.nil? || bourreaux.empty?

    bourreaux_pairs = bourreaux.sort_by(&:name).map do |b|
       opt_pair = [ b.name, b.id.to_s ]
       if (! b.online?) && (! options[:offline_is_ok])
         opt_pair[0] += " (offline)"
         opt_pair << { :disabled => "true" }
       end
       opt_pair #  [ "BoName", "3" ]    or   [ "BoName", "3", { :disabled => "true" } ]
    end
    options_html   = options_for_select(bourreaux_pairs, selected)
    blank_label    = select_tag_options.delete(:include_blank) || options[:include_blank]
    if blank_label
      blank_label  = "" if blank_label == true
      options_html = "<option value=\"\">#{h(blank_label)}</option>".html_safe + options_html
    end

    select_tag parameter_name, options_html, select_tag_options
  end

  # Create a standard tool config select box for selecting a tool config in a form.
  # The +parameter_name+ argument will be the name of the parameter
  # when the form is submitted and the +select_tag_options+ hash will be sent
  # directly as options to the +select_tag+ helper method called to create the element.
  #
  # The +options+ hash can contain either or both of the following:
  #
  # [selector] used for default selection. This can be a ToolConfig object, a ToolConfig id (String or Integer),
  #            or any model that has a tool_config attribute.
  # [tool_configs] the array of ToolConfig objects used to build the select box. Defaults to all tool configs
  #                  accessible by the current_user.
  # [allow_offline] by default the offline tc will be disabled. If this option is set to true the tc will be selectable
  #
  # The selection box will partition the ToolConfig objects by 'categories', where there
  # are three such categories:
  #
  # - ToolConfigs for specific Bourreaux (and any Tools)
  # - ToolConfigs for specific Tools (and any Bourreaux)
  # - ToolConfigs for specific Tools on specific Bourreaux
  #
  def tool_config_select(parameter_name = 'tool_config_id', options = {}, select_tag_options = {})
    options       = { :selector => options } unless options.is_a?(Hash)
    selector      = options[:selector]
    allow_offline = options[:allow_offline] == true ? true : false

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
    tool_configs  = tool_configs.all.to_a if tool_configs.is_a?(ActiveRecord::Relation)

    tool_config_options = []   # [ [ grouplabel, [ [pair], [pair] ] ], [ grouplabel, [ [pair], [pair] ] ] ]

    bourreaux_by_ids = Bourreau.where(:id => tool_configs.map(&:bourreau_id).uniq.compact).all.index_by(&:id)
    tools_by_ids     = Tool.where(    :id => tool_configs.map(&:tool_id).uniq.compact).all.index_by(&:id)

    # Globals for Execution Servers
    bourreau_globals = tool_configs.select { |tc| tc.applies_to_bourreau_only? }
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
    tool_globals = tool_configs.select { |tc| tc.applies_to_tool_only? }
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
    spec_tool_configs  = tool_configs.select { |tc| tc.applies_to_bourreau_and_tool? }
    same_tool          = tool_configs.all?   { |tc| tc.tool_id     == tool_configs[0].tool_id }
    same_bourreau      = tool_configs.all?   { |tc| tc.bourreau_id == tool_configs[0].bourreau_id }

    tcs_by_bourreau_id   = spec_tool_configs.group_by { |tc| tc.bourreau_id }
    ordered_bourreau_ids = tcs_by_bourreau_id.keys.sort { |bid1,bid2| bourreaux_by_ids[bid1].name <=> bourreaux_by_ids[bid2].name }
    ordered_bourreau_ids.each do |bid|
      bourreau              = bourreaux_by_ids[bid]
      b_is_online           = bourreau.online?
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
          desc     = tc.version_name || tc.short_description
          tc_pair  = !b_is_online && !allow_offline ? [ desc, tc.id.to_s, {:disabled => "true"} ] : [ desc, tc.id.to_s ]
          pairlist << tc_pair
        end
        if same_tool && (! same_bourreau || ordered_bourreau_ids.size == 1)
          offline = b_is_online ? "" : " (offline)"
          label = "On #{bourreau.name}#{offline}:"
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

    blank_label = select_tag_options.delete(:include_blank) || options[:include_blank]
    if blank_label
      blank_label = "" if blank_label == true
      grouped_options = "<option value=\"\">#{h(blank_label)}</option>".html_safe + grouped_options
    end

    select_tag parameter_name, grouped_options, select_tag_options
  end

  # Create a standard task by status select box for selecting a task status for a form.
  # The +parameter_name+ argument will be the name of the parameter
  # when the form is submitted and the +select_tag_options+ hash will be sent
  # directly as options to the +select_tag+ helper method called to create the element.
  # The +options+ hash can contain either or both of the following:
  # [selector] used for default selection. This can be a task status.
  # [task_status] the array of task status used to build the select box. Default CbrainTask::ALL_STATUS.
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

    blank_label = select_tag_options.delete(:include_blank) || options[:include_blank]
    if blank_label
      blank_label = "" if blank_label == true
      grouped_options = "<option value=\"\">#{h(blank_label)}</option>".html_safe + grouped_options
    end

    select_tag parameter_name, grouped_options, select_tag_options
  end

  # Create a standard userfiles type select box for selecting a userfile type for a form.
  # The +parameter_name+ argument will be the name of the parameter
  # when the form is submitted and the +select_tag_options+ hash will be sent
  # directly as options to the +select_tag+ helper method called to create the element.
  # The +options+ hash can contain either or both of the following:
  # [selector] used for default selection. This can be a Userfile type.
  # [userfile_types] a list of Userfiles type used to build the select box.
  # [generate_descendants] a boolean if it's true take the descendant of classes in :userfile_types else only take
  # the classes in :userfile_types
  # [:include_top] a boolean only used when :generate_descendants is true, if it's true
  # keep the top and the descendants, otherwise only takes the descendants.
  def userfile_type_select(parameter_name = "file_type", options = {}, select_tag_options = {} )
    options              = { :selector => options } unless options.is_a?(Hash)
    generate_descendants =  options.has_key?(:generate_descendants) ? options[:generate_descendants] : true
    userfile_types       = (options[:userfile_types] || ["SingleFile","FileCollection"]).collect!{|type| type.constantize}
    include_top          = options.has_key?(:include_top) ? options[:include_top] : true

    type_select(parameter_name, options.dup.merge({:types => userfile_types, :generate_descendants => generate_descendants, :include_top => include_top}), select_tag_options)
  end

  # Create a standard groups type select box for selecting a group type for a form.
  # The +parameter_name+ argument will be the name of the parameter
  # when the form is submitted and the +select_tag_options+ hash will be sent
  # directly as options to the +select_tag+ helper method called to create the element.
  # The +options+ hash can contain either or both of the following:
  # [selector] used for default selection. This can be a Group type.
  # [group_types] a list of Groups type used to build the select box.
  # [generate_descendants] a boolean if it's true take the descendant of classes in :group_types else only take
  # the classes in :group_types
  # [:include_top] a boolean only used when :generate_descendants is true, if it's true
  # keep the top and the descendants, otherwise only takes the descendants.
  def group_type_select(parameter_name = "group_type", options = {}, select_tag_options = {} )
    options              = { :selector => options } unless options.is_a?(Hash)
    generate_descendants =  options.has_key?(:generate_descendants) ? options[:generate_descendants] : true
    group_types          = (options[:group_types] || ["SystemGroup", "WorkGroup"]).collect!{|type| type.constantize}
    include_top          = options.has_key?(:include_top) ? options[:include_top] : true

    type_select(parameter_name, options.dup.merge({:types => group_types, :generate_descendants => generate_descendants, :include_top => include_top}), select_tag_options)
  end

  # Create a standard tasks type select box for selecting a task type for a form.
  # The +parameter_name+ argument will be the name of the parameter
  # when the form is submitted and the +select_tag_options+ hash will be sent
  # directly as options to the +select_tag+ helper method called to create the element.
  # The +options+ hash can contain either or both of the following:
  # [selector] used for default selection. This can be a Task type.
  # [task_types] a list of Tasks type used to build the select box.
  # [generate_descendants] a boolean if it's true take the descendant of classes in :task_types else only take
  # the classes in :task_types
  # [:include_top] a boolean only used when :generate_descendants is true, if it's true
  # keep the top and the descendants, otherwise only takes the descendants.
  def task_type_select(parameter_name = "task_type", options = {}, select_tag_options = {} )
    options              = { :selector => options } unless options.is_a?(Hash)
    generate_descendants =  options.has_key?(:generate_descendants) ? options[:generate_descendants] : true
    task_types           = (options[:task_types] || ["PortalTask"]).map { |type| type.constantize rescue nil }.compact
    include_top          = options.has_key?(:include_top) ? options[:include_top] : false

    type_select(parameter_name, options.dup.merge({:types => task_types, :generate_descendants => generate_descendants, :include_top => include_top}), select_tag_options)
  end

  # Create a standard types select box for selecting a types type for a form.
  # The +parameter_name+ argument will be the name of the parameter
  # when the form is submitted and the +select_tag_options+ hash will be sent
  # directly as options to the +select_tag+ helper method called to create the element.
  # The +options+ hash can contain either or both of the following:
  # [selector] used for default selection. This can be a type present in types.
  # [types] a list of types used to build the select box.
  # [generate_descendants] a boolean if it's true take the descendant of classes in :types else only take
  # the classes in :types
  # [:include_top] a boolean only used when :generate_descendants is true, if it's true
  # keep the top and the descendants, otherwise only takes the descendants.
  def type_select(parameter_name = "type", options = {}, select_tag_options = {} )
    options              = { :selector => options } unless options.is_a?(Hash)
    generate_descendants = options[:generate_descendants]
    types                = options[:types]
    include_top          = options[:include_top]
    blank_label          = select_tag_options.delete(:include_blank) || options[:include_blank]
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

  # Create an options_for_select box.
  # The +top+ parameter is the top level type, one with which we start.
  # The +selected+ parameter indicate which element need to be selected
  # [:include_top] indicate if top is or is not keep in final options_for_select
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
       #next if k.cbrain_abstract_model?
       lev = klass_lev[k]
       entry = [ "#{("&nbsp;&nbsp;" * lev)}#{k.pretty_type}".html_safe, k.name ]
       entry << { :disabled => "true" } if k.cbrain_abstract_model?
       ordered_type_grouped << entry
    end

    options_for_select ordered_type_grouped, selected
  end

  # Group a list of users into two sub-categories:
  # one for active users and another for locked users
  def regroup_users_by_lock_status(users) #:nodoc:
    user_by_lock_status_hash = users.to_a.hashed_partition { |u| u.account_locked == false ? "Active users" : "Locked users"}
    ordered_by_lock_status   = []

    user_by_lock_status_hash.sort.each do |status,users_by_status|
      user_name_id = users_by_status.sort_by { |u| u.login }.map { |u| ["#{u.login} (#{u.full_name})" , u.id] }
      ordered_by_lock_status << [status, user_name_id]
    end

    ordered_by_lock_status
  end

  # DPs where people can move/copy/extract stuff
  def writable_data_providers(user=current_user)

    writable_data_providers =
      DataProvider
        .find_all_accessible_by_user(current_user)
        .all
        .reject { |dp| dp.read_only? || dp.is_a?(ScratchDataProvider) }

    return writable_data_providers
  end

  # DPs where people can upload stuff (subset of writable_dps)
  def uploadable_data_providers(user=current_user)

    uploadable_data_providers = writable_data_providers(user)
                                 .reject { |dp| dp.meta[:no_uploads].present? }

    return uploadable_data_providers
  end

end

