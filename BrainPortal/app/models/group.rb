
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

#Model representing the Group resource. Groups are meant to represented collective access
#to certain files (analogous to groups of the Unix OS).
#
#=Attributes:
#[*name*] A string representing the name of the group.
#= Associations:
#*Has* *and* *belongs* *to* *many*:
#* User
#*Has* *many*:
#* Userfile
#* DataProvider
#* RemoteResource
#=Dependencies
#[<b>On Destroy</b>] All Userfile, RemoteResource and DataProvider
#                    associated with the group being destroyed will
#                    have their group set to their owner's SystemGroup.
class Group < ApplicationRecord

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  include CustomLicense

  cbrain_abstract_model! # objects of this class are not to be instanciated

  before_validation       :set_default_creator
  after_destroy           :reassign_models_to_owner_group

  validates               :name,
                          :presence => true,
                          :name_format => true

  has_many                :tools
  has_many                :userfiles
  has_many                :data_providers
  has_many                :remote_resources
  has_many                :cbrain_tasks
  has_many                :tags
  # Resource usage is kept forever even if group is destroyed.
  has_many                :resource_usage

  belongs_to              :site, :optional => true
  belongs_to              :creator, :class_name => "User", :optional => true

  has_and_belongs_to_many :users, after_remove: :after_remove_user
  has_and_belongs_to_many :access_profiles
  has_and_belongs_to_many :editors, :class_name => 'User', join_table: 'groups_editors', before_add: :editor_can_be_added!

  scope                   :without_everyone, -> { where([ "groups.id <> ?", Group.everyone_id ]) }

  api_attr_visible        :name, :description, :type, :site_id, :invisible

  # Returns the unique and special group 'everyone'
  def self.everyone
    @everyone ||= EveryoneGroup.find_by_name('everyone')
  end

  def self.everyone_id #:nodoc:
    @everyone_id ||= self.everyone.id
  end

  # Returns itself; this method is here to make it symmetrical
  # with other resource classes such as User and Site, which
  # both have a meaningful own_group() method.
  def own_group
    self
  end

  # Can this group be accessed by +user+?
  def can_be_accessed_by?(user, access_requested = :read)
    @can_be_accessed_cache       ||= {}
    # Check for cached value
    return @can_be_accessed_cache[user.id] unless @can_be_accessed_cache[user.id].nil?
    # Case by case
    return @can_be_accessed_cache[user.id] = true if user.has_role?(:admin_user)
    return @can_be_accessed_cache[user.id] = true if self.creator_id == user.id
    return @can_be_accessed_cache[user.id] = true if user.is_member_of_group(self) # maybe restrict on acces_req?
    return @can_be_accessed_cache[user.id] = true if user.has_role?(:site_manager) && user.site.group_ids.include?(self.id)
    return @can_be_accessed_cache[user.id] = (access_requested == :read) if self.public?
    return @can_be_accessed_cache[user.id] = false
  end

  # Can this group be edited by +user+?
  #
  # Returns false in general. Should be overidden in subclasses
  # in cases where editing is possible.
  def can_be_edited_by?(user)
    false
  end

  # Returns a 'group category name' as seen by +as_user+.
  def pretty_category_name(as_user = nil)
    @_pretty_category_name ||= self.class.pretty_type
  end

  def pretty_type #:nodoc:
    @_pretty_type ||= self.class.pretty_type
  end

  def self.pretty_type #:nodoc:
    @_pretty_type ||= self.to_s.demodulize.underscore.titleize.sub(/group/i,"Project")
  end

  def short_pretty_type #:nodoc:
   self.class.short_pretty_type
  end

  def self.short_pretty_type #:nodoc:
    self.to_s.demodulize.underscore.titleize.sub(/\s*group\s*/i,"")
  end

  # Validation for join table editors_groups
  def editor_can_be_added!(user) #:nodoc:
    cb_error "Must be redefined in subclasses."
  end

  # Should be redefined in subclasses
  def after_remove_user(user) #:nodoc:
    true
  end

  ##################################
  # Public Group support methods
  ##################################

  def self.public_groups #:nodoc:
    self.where(:public => true)
  end

  def self.public_group_ids #:nodoc:
    self.public_groups.pluck(:id)
  end

  private

  # Set creator id if it's not set.
  def set_default_creator #:nodoc:
    admin_user = User.admin
    if self.creator_id.nil? && admin_user #if admin doesn't exist it should mean that it's a new system.
      self.creator_id = admin_user.id
    end
  end

  # After destroy callback
  def reassign_models_to_owner_group #:nodoc:
    group_has_many_model_list = Group.reflect_on_all_associations.select { |a| a.macro == :has_many }.map { |a| a.name }
    objlist = group_has_many_model_list.inject([]) { |list,modsym| list += self.send(modsym) }
    user_id_to_own_group_id = {}
    objlist.each do |obj|
      own_group_id = user_id_to_own_group_id[obj.user_id] ||= obj.user.own_group.id
      obj.update_attributes!( :group_id => own_group_id )
    end
  end

end
