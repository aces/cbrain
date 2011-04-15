
#
# CBRAIN Project
#
# Group model
#
# Original author: Tarek Sherif
#
# $Id$
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
class Group < ActiveRecord::Base

  Revision_info="$Id$"

  before_destroy          :assign_userfile_to_owner_group,
                          :assign_remote_resource_to_owner_group,
                          :assign_data_provider_to_owner_group,
                          :assign_task_to_owner_group
  
  validates_presence_of   :name
  validates_uniqueness_of :name
  
  has_many                :tools
  has_and_belongs_to_many :users 
  has_many                :userfiles
  has_many                :data_providers 
  has_many                :remote_resources
  has_many                :cbrain_tasks
  belongs_to              :site 

  # Returns the unique and special group 'everyone'
  def self.everyone
    @everyone ||= self.find_by_name('everyone')
  end

  # Returns itself; this method is here to make it symetrical
  # with other resource classes such as User and Site, which
  # both have a meaningful own_group() method.
  def own_group
    self
  end

  def can_be_accessed_by?(user, access_requested = :read) #:nodoc:
    @can_be_accessed_cache       ||= {}
    @can_be_accessed_cache[user] ||= (user.has_role?(:admin) || user.is_member_of_group(self))
  end
  
  #Can this group be edited by +user+?
  #
  #Returns false in general. Should be overidden in subclasses
  #in cases where editing is possible.
  def can_be_edited_by?(user)
    false
  end

  private
  
  def assign_userfile_to_owner_group #:nodoc:
    user_group = {}
    self.userfiles.each do |file|
      user = file.user
      user_group[user.id] ||= SystemGroup.find_by_name(user.login)
      
      file.update_attributes!(:group => user_group[user.id])
    end
  end
  
  def assign_remote_resource_to_owner_group #:nodoc:
    user_group = {}
    self.remote_resources.each do |rr|
      user = rr.user
      user_group[user.id] ||= SystemGroup.find_by_name(user.login)
      
      rr.update_attributes!(:group => user_group[user.id])
    end
  end
  
  def assign_data_provider_to_owner_group #:nodoc:
    user_group = {}
    self.data_providers.each do |dp|
      user = dp.user
      user_group[user.id] ||= SystemGroup.find_by_name(user.login)
      
      dp.update_attributes!(:group => user_group[user.id])
    end
  end

  def assign_task_to_owner_group #:nodoc:
    user_group = {}
    self.cbrain_tasks.each do |task|
      user = task.user
      user_group[user.id] ||= SystemGroup.find_by_name(user.login)
      
      task.update_attributes!(:group => user_group[user.id])
    end
  end

end
