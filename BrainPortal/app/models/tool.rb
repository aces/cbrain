
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

#Model representing CBrain tools. 
#The purpose of the tools model is to create an inventory of the tools for each bourreau.
#
#=Attributes:
#[*name*] The name of the tool.
#[*cbrain_task_class*] CbrainTask subclass associated with this tool.
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

  Revision_info=CbrainFileRevision[__FILE__]
  
  include ResourceAccess
  
  Categories = ["scientific tool", "conversion tool", "background"]
  
  before_validation :set_default_attributes
  
  validates_uniqueness_of :name, :select_menu_text, :cbrain_task_class
  validates_presence_of   :name, :cbrain_task_class, :user_id, :group_id, :category, :select_menu_text, :description
  validates_inclusion_of  :category, :in => Categories
  
  belongs_to              :user
  belongs_to              :group
  has_many                :tool_configs, :dependent => :destroy
  has_many                :bourreaux, :through => :tool_configs, :uniq => true

  attr_accessible         :name, :user_id, :group_id, :category, 
                          :cbrain_task_class, :select_menu_text, :description

  # CBRAIN extension
  force_text_attribute_encoding 'UTF-8', :description

  #Find a random bourreau on which this tool is available and to which +user+ has access.
  def select_random_bourreau_for(user)
    available_group_ids = user.group_ids
    bourreau_list = Bourreau.where( :group_id => available_group_ids, :online => true ).select(&:is_alive?)
    bourreau_list = bourreau_list & self.bourreaux
    if bourreau_list.empty?
      cb_error("Unable to find an execution server. Please notify your administrator of the problem.")
    end
    bourreau_list.slice(rand(bourreau_list.size)).id
  end

  # Returns the single ToolConfig object that describes the configuration
  # for this tool for all Bourreaux, or nil if it doesn't exist.
  def global_tool_config
    @global_tool_config_cache ||= ToolConfig.where( :tool_id => self.id, :bourreau_id => nil ).first
  end

  private
  
  def set_default_attributes #:nodoc:
    self.select_menu_text ||= "Launch #{self.name}"
    self.description ||= "#{self.name}"
  end

end
