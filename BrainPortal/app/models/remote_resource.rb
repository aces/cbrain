
#
# CBRAIN Project
#
# Original author: Pierre Rioux
#
# $Id$
#

#Model representing the remote services. 
#
#=Attributes:
#[*name*] A string representing a the name of the remote resource.
#[*type*] A string representing a the type of remote resource.
#[*remote_user*] A string representing a user name to use to access the remote site.
#[*remote_host*] A string representing a the hostname of the remote resource.
#[*remote_port*] An integer representing the port number of the remote resource.
#[*remote_dir*] An string representing the directory of the remote resource.
#[*online*] A boolean value set to whether or not the resource is online.
#[*read_only*] A boolean value set to whether or not the resource is read only.
#[*description*] Text with a description of the remote resource.
#
#= Associations:
#*Belongs* *to*:
#* User
#* Group
class RemoteResource < ActiveRecord::Base

  Revision_info="$Id$"

  validates_uniqueness_of :name
  validates_presence_of   :name, :user_id, :group_id

  validate :valid_name?  # makes sure the name is a simple identifier

  belongs_to  :user
  belongs_to  :group

  #Returns whether or not this resource can be accessed by +user+.
  def can_be_accessed_by(user)
    user.group_ids.include?(group_id)
  end

  #Returns whether or not this resource is active.
  def is_alive?
    false
  end

  protected

  # Makes sure that the record has a valid simple name
  def valid_name? #:nodoc:
    name = self.name
    return false unless name && name.match(/^[a-zA-Z0-9][\w\-\=\.\+]*$/)
    true
  end

end
