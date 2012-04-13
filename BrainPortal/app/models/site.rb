
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

class Site < ActiveRecord::Base
  
  Revision_info=CbrainFileRevision[__FILE__]
                                                               
  validates              :name, 
                         :presence => true,
                         :uniqueness => true,
                         :name_format => true
                         
  validate               :prevent_group_collision, :on => :create
                         
  before_create          :create_system_group
  
  before_save            :save_old_manager_ids,
                         :save_old_user_ids   

  after_save             :set_managers,
                         :set_system_groups

  after_update           :system_group_rename

  before_destroy         :unset_managers,
                         :destroy_system_group
  
  
  has_many        :users,  :dependent => :nullify, :after_remove  => [:user_system_group_remove, :remove_user_from_site_group]
  has_many        :groups, :dependent => :nullify
  
  # CBRAIN extension
  force_text_attribute_encoding 'UTF-8', :description
  
  attr_accessor           :manager_ids


  #Returns users that have manager access to this site (site managers or admins).
  def managers
    self.users.where( ["(users.role IN (?))", ["admin", "site_manager"]]) || []
  end
  
  #Find all userfiles that belong to users associated with this site, subject to +options+ (ActiveRecord where options).
  def userfiles_find_all(options = {})
    scope = Userfile.where(options)
    scope = scope.joins(:user).where( ["users.site_id = ?", self.id] ).readonly(false)
    scope
  end
  
  #Find all remote resources that belong to users associated with this site, subject to +options+ (ActiveRecord where options).
  def remote_resources_find_all(options = {})
    scope = RemoteResource.where(options)
    scope = scope.joins(:user).where( ["users.site_id = ?", self.id] ).readonly(false)
    scope
  end
  
  #Find all data providers that belong to users associated with this site, subject to +options+ (ActiveRecord where options).
  def data_providers_find_all(options = {})
    scope = DataProvider.where(options)
    scope = scope.joins(:user).where( ["users.site_id = ?", self.id] ).readonly(false)
    scope
  end
  
  #Find all tools that belong to users associated with this site, subject to +options+ (ActiveRecord where options).
  def tools_find_all(options = {})
    scope = Tool.where(options)
    scope = scope.joins(:user).where( ["users.site_id = ?", self.id] ).readonly(false)
    scope
  end
  
  #Find the userfile with the given +id+ that belong to a user associated with this site, subject to +options+ (ActiveRecord where options).
  def userfiles_find_id(id, options = {})
    scope = Userfile.where(options)
    scope = scope.joins(:user).where( ["users.site_id = ?", self.id] ).readonly(false)
    scope.find(id)
  end
  
  #Find the remote resource with the given +id+ that belong to a user associated with this site, subject to +options+ (ActiveRecord where options).
  def remote_resources_find_id(id, options = {})
    scope = RemoteResource.where(options)
    scope = scope.joins(:user).where( ["users.site_id = ?", self.id] ).readonly(false)
    scope.find(id)
  end
  
  #Find the data provider with the given +id+ that belong to a user associated with this site, subject to +options+ (ActiveRecord where options).
  def data_providers_find_id(id, options = {})
    scope = DataProvider.where(options)
    scope = scope.joins(:user).where( ["users.site_id = ?", self.id] ).readonly(false)
    scope.find(id)
  end
  
  #Find the tool with the given +id+ that belong to a user associated with this site, subject to +options+ (ActiveRecord where options).
  def tools_find_id(id, options = {})
    scope = Tool.where(options)
    scope = scope.joins(:user).where( ["users.site_id = ?", self.id] ).readonly(false)
    scope.find(id)
  end
  
  # Returns the SystemGroup associated with the site; this is a
  # group with the same name as the site.
  def system_group
    @own_group ||= SiteGroup.where( :name => self.name ).first
  end

  # An alias for system_group()
  alias own_group system_group

  def unset_managers #:nodoc:
    @old_managers = []
    self.managers.each do |user|
      if user.has_role? :site_manager # could be :admin too, which we leave alone
        @old_managers << user
        user.update_attribute(:role, "user")
      end
    end
  end
  
  def restore_managers #:nodoc:
    @old_managers ||= []
    @old_managers.each do |user|
      user.update_attribute(:role, "site_manager")
    end
  end
  
  private
  
  def create_system_group #:nodoc:
    site_group = SiteGroup.new(:name => self.name, :site_id  => self.id)
    unless site_group.save
      self.errors.add(:base, "Site Group: #{site_group.errors.full_messages.join(", ")}")
      return false
    end
  end
  
  def user_system_group_remove(user) #:nodoc:
    if user.has_role? :site_manager
      user.update_attributes!(:role  => "user")
    end
    user.own_group.update_attributes!(:site => nil)
  end
  
  def remove_user_from_site_group(user) #:nodoc:
    self.own_group.users.delete(user)
  end
  
  def save_old_manager_ids #:nodoc:
    @old_manager_ids = self.managers.map &:id
  end
  
  def save_old_user_ids #:nodoc:
    @old_user_ids = self.users.map &:id
  end
  
  def set_managers #:nodoc:
    self.manager_ids ||= []
    self.user_ids    ||= []
    current_manager_ids = self.manager_ids || []
    current_user_ids    = self.user_ids
    User.find(current_user_ids | current_manager_ids).each do |user|
      user.site_id = self.id
      if current_manager_ids.include?(user.id)
        if user.has_role? :user
          user.role = "site_manager"
        end                
      elsif user.has_role? :site_manager
        user.role = "user"
      end
      user.save(:validate => false)
    end
  end
  
  def set_system_groups #:nodoc:
    current_user_ids = self.user_ids || []
    @new_user_ids   = current_user_ids - @old_user_ids
    @unset_user_ids = @old_user_ids - current_user_ids
    site_group = self.own_group
    
    unless site_group.blank? || self.groups.exists?(site_group)
      self.groups << site_group
    end
    
    User.find(@new_user_ids).each do |user|
      user.own_group.update_attributes!(:site => self)
      unless site_group.blank? || self.groups.exists?(site_group)
        user.groups << site_group
      end
    end
  end
  
  def system_group_rename #:nodoc:
    if self.changed.include?("name")
      old_name = self.changes["name"].first
      SiteGroup.find_by_name(old_name).update_attributes!(:name => self.name)
    end
  end
  
  def prevent_group_collision #:nodoc:
    if self.name && SystemGroup.find_by_name(self.name)
      errors.add(:name, "already in use by an existing project.")
    end
  end
  
  def destroy_system_group #:nodoc:
    system_group = self.own_group
    system_group.destroy if system_group
  end
end
