#Helpers for resource links.
module ResourceLinkHelper

  Revision_info="$Id"
  
  #################################################################################
  # Link Helpers
  #################################################################################
  
  #Creates a link labeled +name+ to the url +path+ *if* *and* *only* *if*
  #the current user has a role of *admin*. Otherwise, +name+ will be 
  #displayed as static text.
  def link_if_admin(name, path)
    if check_role(:admin)
      link_to(name, path)
    else
      name
    end
  end
  
  #Creates a link labeled +name+ to the url +path+ *if* *and* *only* *if*
  #the current user has a role of *admin* or <b>site manager</b>. Otherwise, +name+ will be 
  #displayed as static text.
  def link_if_manager(name, path)
    if check_role(:admin) || check_role(:site_manager)
      link_to(name, path)
    else
      name
    end
  end
  
  #Creates a link labeled +name+ to the url +path+ *if* *and* *only* *if*
  #the current user has access to +resource+. Otherwise, +name+ will be 
  #displayed as static text.
  def link_if_has_access(resource, name, path)
    if resource.can_be_accessed_by?(current_user)
      link_to(name, path)
    else
      name
    end
  end

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
  # current_user.
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
    link_to_model_if_accessible(Group,group,:name,cur_user,options)
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
    model_obj = model_obj_or_id
    if model_obj_or_id.is_a?(String) || model_obj_or_id.is_a?(Fixnum)
      model_obj = model_class.find(model_obj_or_id) rescue nil
      return "(Deleted/Non-existing)" if model_obj.blank?
    end
    name = options[:name] || model_obj.send(model_name_method)
    path = options[:path]
    path ||= send("#{model_class.to_s.underscore}_path",model_obj.id)     rescue nil
    path ||= send("#{model_obj.class.to_s.underscore}_path",model_obj.id) rescue nil
    if !path # other special cases
      path = task_path(model_obj.id)     if model_class <= CbrainTask
      path = bourreau_path(model_obj.id) if model_class <= BrainPortal
    end
    user ||= current_user
    if ((!model_obj.respond_to?(:available?)          || model_obj.available?) &&
        (!model_obj.respond_to?(:can_be_accessed_by?) || model_obj.can_be_accessed_by?(user, :read)))
      link_to(name, path)
    else
      name
    end
  end

  

end