
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

# Module containing common methods for the models representing
# resources owned by certain users and made available to others
# through groups (currently RemoteResource, DataProvider).
#
# This requires that classes that include them be ActiveRecord models
# with at least the attributes +user_id+ and +group_id+.

module ResourceAccess

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Check that the the class this module is being included into is a valid one.
  def self.included(includer) #:nodoc:
    return unless includer.table_exists?

    unless includer < ApplicationRecord
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
  # The +access_requested+ params is not used right now (reserved for future extension).
  def can_be_accessed_by?(user, access_requested = :read)
    return true if self.user_id == user.id || user.has_role?(:admin_user)
    return true if user.has_role?(:site_manager) && self.user.site_id == user.site_id
    user.is_member_of_group(group_id)
  end

  # Returns whether or not +user+ has owner access to this
  # resource.
  def has_owner_access?(user)
    if user.has_role? :admin_user
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
    # Find resource identified by +id+ accessible by +user+.
    #
    # *Accessible* resources  are:
    # [For *admin* users:] any resource on the system.
    # [For regular users:] all resources that belong to a group to which the user belongs.
    def find_accessible_by_user(id, user, options = {})
      find_all_accessible_by_user(user, options).find(id)
    end

    # Find all resources accessible by +user+.
    #
    # *Accessible* resources  are:
    # [For *admin* users:] any resource on the system.
    # [For regular users:] all resources that belong to a group to which the user belongs.
    def find_all_accessible_by_user(user, options = {})
      scope = self.where(options) # will fail if not simple attribute mappings

      return scope if user.has_role? :admin_user

      scope     = scope.joins(:user)
      available_group_ids = (user.group_ids + Group.where(:public => true).pluck(:id) + Group.where(:type => "EveryoneGroup").pluck(:id)).uniq

      if user.has_role? :site_manager
        scope = scope.where(["(#{self.table_name}.user_id = ?) OR (#{self.table_name}.group_id IN (?)) OR (users.site_id = ?)",
                                                            user.id,                               available_group_ids,    user.site_id])
      else
        scope = scope.where(["(#{self.table_name}.user_id = ?) OR (#{self.table_name}.group_id IN (?))",
                                                            user.id,                               available_group_ids])
      end

      scope
    end
  end
end

