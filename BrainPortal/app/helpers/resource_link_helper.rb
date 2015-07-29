
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

# Helpers for resource links.
module ResourceLinkHelper

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:
  
  # Creates a link to the show page of a +userfile+, as long
  # as the +cur_user+ has access to it. By default, +cur_user+ is
  # current_user.
  #
  # +userfile+ can be provided as an ID too.
  #
  # If the ID is nil, then the string
  #   "(None)"
  # will be returned.
  #
  # If the ID is invalid, the string
  #   "(Deleted/Non-existing)"
  # will be returned.
  #
  # +options+ can contain a :name for
  # the link (the default is the userfile's name) and a
  # :path (the default is the show path).
  def link_to_userfile_if_accessible(userfile, cur_user = current_user, options = {})
    link_to_model_if_accessible(Userfile,userfile,:name,cur_user,options)
  end

  # Creates a link to the show page of a +user+, as long
  # as the +cur_user+ has access to it. By default, +cur_user+ is
  # current_user. The link will be shown in red (error_link class)
  # if the user is currently locked.
  #
  # +user+ can be provided as an ID too.
  #
  # If the ID is nil, then the string
  #   "(None)"
  # will be returned.
  #
  # If the ID is invalid, the string
  #   "(Deleted/Non-existing)"
  # will be returned.
  #
  # +options+ can contain a :name for
  # the link (the default is the user's login name) and a
  # :path (the default is the show path).
  def link_to_user_if_accessible(user, cur_user = current_user, options = {})
    user = User.find(user) unless user.is_a?(User)
    (options[:html_options] ||= {})[:class] = 'error_link' if user.account_locked
    link_to_model_if_accessible(User,user,:login,cur_user,options)
  end

  # Creates a link to the show page of a +data_provider+, as long
  # as the +cur_user+ has access to it. By default, +cur_user+ is
  # current_user.
  #
  # +data_provider+ can be provided as an ID too.
  #
  # If the ID is nil, then the string
  #   "(None)"
  # will be returned.
  #
  # If the ID is invalid, the string
  #   "(Deleted/Non-existing)"
  # will be returned.
  #
  # +options+ can contain a :name for
  # the link (the default is the data provider's name) and a
  # :path (the default is the show path).
  def link_to_data_provider_if_accessible(dp, cur_user = current_user, options = {})
    link_to_model_if_accessible(DataProvider,dp,:name,cur_user,options)
  end

  # Creates a link to the show page of a +bourreau+, as long
  # as the +cur_user+ has access to it. By default, +cur_user+ is
  # current_user.
  #
  # +bourreau+ can be provided as an ID too.
  #
  # If the ID is nil, then the string
  #   "(None)"
  # will be returned.
  #
  # If the ID is invalid, the string
  #   "(Deleted/Non-existing)"
  # will be returned.
  #
  # +options+ can contain a :name for
  # the link (the default is the bourreau's name) and a
  # :path (the default is the show path).
  def link_to_bourreau_if_accessible(bourreau, cur_user = current_user, options = {})
    link_to_model_if_accessible(Bourreau,bourreau,:name,cur_user,options)
  end

  # Creates a link to the show page of a +group+, as long
  # as the +cur_user+ has access to it. By default, +cur_user+ is
  # current_user.
  #
  # +group+ can be provided as an ID too.
  #
  # If the ID is nil, then the string
  #   "(None)"
  # will be returned.
  #
  # If the ID is invalid, the string
  #   "(Deleted/Non-existing)"
  # will be returned.
  #
  # +options+ can contain a :name for
  # the link (the default is the group's name) and a
  # :path (the default is the show path).
  def link_to_group_if_accessible(group, cur_user = current_user, options = {})
    the_id = group.is_a?(Group) ? group.id : ( group.to_i rescue 0 )
    return "everyone" if the_id == Group.everyone.id && ! cur_user.has_role?(:admin_user) # special case
    link_to_model_if_accessible(Group,group,:name,cur_user,options)
  end

  # This method works like link_to_group_if_accessible() except that
  # the link is created only if the group is a WorkGroup. 
  # The first argument MUST be an actual group.
  # The link created will be to the edit page of the group.
  def link_to_group_if_editable(group, cur_user = current_user, options = {})
    if group.is_a?(WorkGroup)
      link_to_group_if_accessible(group, cur_user, options.dup.merge(:path => group_path(group)))
    else
      group.name
    end
  end

  # Creates a link to the show page of a +site+, as long
  # as the +cur_user+ has access to it. By default, +cur_user+ is
  # current_user.
  #
  # +site+ can be provided as an ID too.
  #
  # If the ID is nil, then the string
  #   "(None)"
  # will be returned.
  #
  # If the ID is invalid, the string
  #   "(Deleted/Non-existing)"
  # will be returned.
  #
  # +options+ can contain a :name for
  # the link (the default is the site's name) and a
  # :path (the default is the show path).
  def link_to_site_if_accessible(site, cur_user = current_user, options = {})
    link_to_model_if_accessible(Site,site,:name,cur_user,options)
  end

  # Creates a link to the show page of a +task+, as long
  # as the +cur_user+ has access to it. By default, +cur_user+ is
  # current_user.
  #
  # +task+ can be provided as an ID too.
  #
  # If the ID is nil, then the string
  #   "(None)"
  # will be returned.
  #
  # If the ID is invalid, the string
  #   "(Deleted/Non-existing)"
  # will be returned.
  #
  # +options+ can contain a :name for
  # the link (the default is the task's name) and a
  # :path (the default is the show path).
  def link_to_task_if_accessible(task, cur_user = current_user, options = {})
    link_to_model_if_accessible(CbrainTask,task,:name,cur_user,options)
  end

  # Implements the link_to_{SOMETHING}_if_available() methods
  # where SOMETHING is one of CBRAIN's models. The method will
  # check for as many access privileges as the object's model supports;
  # if any access is denied, the link will not be a href, but just
  # the name of the object.
  def link_to_model_if_accessible(model_class, model_obj_or_id, model_name_method = :name, user = current_user, options = {}) #:nodoc:
    return "(None)" if model_obj_or_id.blank?
    user ||= current_user # allows us to supply 'nil' in arg
    model_obj = model_obj_or_id
    if model_obj_or_id.is_a?(String) || model_obj_or_id.is_a?(Fixnum)
      model_obj = model_class.find(model_obj_or_id) rescue nil
      return "(Deleted/Non-existing)" if model_obj.blank?
    end
    model_name_method = options[:name_method] if options[:name_method]  # allows overriding
    query_params      = options[:query_params] || {}
    name = options[:name] || model_obj.send(model_name_method)
    path = options[:path]
    path ||= send("#{model_class.to_s.underscore}_path",model_obj.id,query_params)     rescue nil
    path ||= send("#{model_obj.class.to_s.underscore}_path",model_obj.id,query_params) rescue nil
    if !path # other special cases
      path = task_path(model_obj.id)     if model_class <= CbrainTask
      path = bourreau_path(model_obj.id) if model_class <= BrainPortal
    end
    user ||= current_user
    if (
      # (!model_obj.respond_to?(:available?)          || model_obj.available?) &&
        (!model_obj.respond_to?(:can_be_accessed_by?) || model_obj.can_be_accessed_by?(user, :read))
       )
       html_options = options[:html_options] || {}
       link_to(name, path, html_options)
    else
      name
    end
  end

  # Same as link_to_user_if_accessible (but requires a legal
  # user object) and adds a tooltip with a summary of the
  # user's information (full name, site and city).
  def link_to_user_with_tooltip(user, cur_user = current_user, options = {})
    return "(None)" if user.blank?
    cb_error "This method requires the first argument to be a User object." unless user.is_a?(User)
    capture do
      html_tool_tip(link_to_user_if_accessible(user,current_user,options), :offset_x => 60 ) do
        (
        "<div class=\"left_align\">\n" +
        "#{h(user.full_name)}<br>\n" +
        (user.city.blank?  ? "" : "City: #{h(user.city)}<br/>\n") +
        (user.site.blank?  ? "" : "Site: #{h(user.site.name)}<br/>\n") +
        (user.email.blank? ? "" : "Email: #{h(user.email)}<br/>\n") +
        "</div>"
        ).html_safe
      end
    end
  end

end
