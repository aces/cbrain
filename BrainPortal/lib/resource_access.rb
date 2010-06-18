
#
# CBRAIN Project
#
# Module containing common methods for resource access.
#
# Original author: Tarek Sherif
#
# $Id$
#

# Module containing common methods for the models representing
# resources owned by certain users and made available to others
# through groups (currently RemoteResource, DataProvider).
#
# This requires that classes that include them be ActiveRecord models
# with at least the attributes +user_id+ and +group_id+.
module ResourceAccess

  Revision_info="$Id$"
  
  #Check that the the class this module is being included into is a valid one.
  def self.included(includer)
    unless includer < ActiveRecord::Base
      raise "#{includer} is not an ActiveRecord model. The ResourceAccess module cannot be used with it."
    end
    
    unless includer.column_names.include?("user_id") && includer.column_names.include?("group_id")
      raise "The ResourceAccess module requires 'user_id' and 'group_id' attributes to function. #{includer} does not contain them."
    end
    
    includer.class_eval do
      extend ClassMethods
    end
  end
  
  # Returns true if +user+ can access this resource.
  def can_be_accessed_by?(user)
    return true if self.user_id == user.id || user.has_role?(:admin)
    return true if user.has_role?(:site_manager) && self.user.site_id == user.site_id
    user.group_ids.include?(group_id)
  end

  #Returns whether or not +user+ has owner access to this
  #resource.
  def has_owner_access?(user)
    if user.has_role? :admin
      return true
    end
    if user.has_role?(:site_manager) && self.user.site_id == user.site_id && self.group.site_id == user.site_id
      return true
    end
    if user.id == self.user_id
      return true
    end
  
    false
  end

  module ClassMethods
    #Find resource identified by +id+ accessible by +user+.
    #
    #*Accessible* resources  are:
    #[For *admin* users:] any resource on the system.
    #[For regular users:] all resources that belong to a group to which the user belongs.
    def find_accessible_by_user(id, user, options = {})
      scope = self.scoped(options)
    
      unless user.has_role? :admin
        scope = scope.scoped(:joins  => :user, :readonly  => false)
      
        if user.has_role? :site_manager
          scope = scope.scoped(:conditions  => ["(#{self.table_name}.user_id = ?) OR (#{self.table_name}.group_id IN (?)) OR (users.site_id = ?)", user.id, user.group_ids, user.site_id])
        else
          scope = scope.scoped(:conditions  => ["(#{self.table_name}.user_id = ?) OR (#{self.table_name}.group_id IN (?))", user.id, user.group_ids])
        end
      end
    
      scope.find(id)
    end
  
    #Find all resources accessible by +user+.
    #
    #*Accessible* resources  are:
    #[For *admin* users:] any resource on the system.
    #[For regular users:] all resources that belong to a group to which the user belongs.
    def find_all_accessible_by_user(user, options = {})
      scope = self.scoped(options)
    
      unless user.has_role? :admin
        scope = scope.scoped(:joins  => :user, :readonly  => false)
      
        if user.has_role? :site_manager
          scope = scope.scoped(:conditions  => ["(#{self.table_name}.user_id = ?) OR (#{self.table_name}.group_id IN (?)) OR (users.site_id = ?)", user.id, user.group_ids, user.site_id])
        else
          scope = scope.scoped(:conditions  => ["(#{self.table_name}.user_id = ?) OR (#{self.table_name}.group_id IN (?))", user.id, user.group_ids])
        end
      end
    
      scope.find(:all)
    end
  end
end
