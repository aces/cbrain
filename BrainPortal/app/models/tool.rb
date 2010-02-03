#
# CBRAIN Project
#
# Tool controller for the BrainPortal interface
#
# Original author: Angela McCloskey
#
# Revision_info="$Id$"
#

#Model representing CBrain tools. 
#The purpose of the tools model is to create an inventory of the tools for each bourreau.
#
#=Attributes:
#[*name*] The name of the tool.
#[*drmaa_class*] DrmaaTask subclass associated with this tool.
#[*user_id*] The owner of the tool.
#[*group_id*] The group that the tool belongs to.
#[*category*]  The category that the tool belongs to.
#= Associations:
#*Belongs* *to*:
#* User
#* Group
#*Has* *and* *belongs* *to* *many*
#* Bourreau
class Tool < ActiveRecord::Base
  Revision_info="$Id$"
  
  Categories = ["scientific tool", "conversion tool"]
  
  before_validation :set_default_attributes
  
  belongs_to :user
  belongs_to :group
  has_and_belongs_to_many :bourreaux
  
  validates_uniqueness_of :name, :select_menu_text, :drmaa_class
  validates_presence_of   :name, :drmaa_class, :user_id, :group_id, :category, :select_menu_text, :description
  validates_inclusion_of  :category, :in => Categories
  
  def select_random_bourreau_for(user)
    available_group_ids = user.group_ids
    bourreau_list = self.bourreaux.find(:all, :conditions => { :group_id => available_group_ids, :online => true }).select(&:is_alive?)
    if bourreau_list.empty?
      cb_error("Unable to find an execution server. Please notify your administrator of the problem.")
    end
    bourreau_list.slice(rand(bourreau_list.size)).id
  end
  
  private
  
  def set_default_attributes
    self.select_menu_text ||= "Launch #{self.name}"
    self.description ||= "#{self.name}"
  end
end
