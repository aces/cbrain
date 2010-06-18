
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
  has_many                :tools
  has_and_belongs_to_many :users 
  has_many                :userfiles
  has_many                :data_providers 
  has_many                :remote_resources
  belongs_to              :site 

  validates_presence_of   :name
  validates_uniqueness_of :name
  
  before_destroy          :assign_userfile_to_owner_group,
                          :assign_remote_resource_to_owner_group,
                          :assign_data_provider_to_owner_group
  
  # Returns itself; this method is here to make it symetrical
  # with other resource classes such as User and Site, which
  # both have a meaningful own_group() method.
  def own_group
    self
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

end
