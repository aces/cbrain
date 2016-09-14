
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
#[*cbrain_task_class_name*] The name of the CbrainTask subclass associated with this tool.
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

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  include ResourceAccess
  include LicenseAgreements

  Categories = ["scientific tool", "conversion tool", "background"]

  before_validation :set_default_attributes

  validates_uniqueness_of :name, :select_menu_text, :cbrain_task_class_name
  validates_presence_of   :name, :cbrain_task_class_name, :user_id, :group_id, :category, :select_menu_text, :description
  validates_inclusion_of  :category, :in => Categories
  validates_format_of :url, :with => URI::regexp(%w(http https)), :if => :url_present?


  belongs_to              :user
  belongs_to              :group
  has_many                :tool_configs, :dependent => :destroy
  has_many                :bourreaux, :through => :tool_configs, :uniq => true

  attr_accessible         :name, :user_id, :group_id, :category, :license_agreements,
                          :cbrain_task_class_name, :select_menu_text, :description, :url,
                          :application_type, :application_tags, :application_package_name

  # Returns the single ToolConfig object that describes the configuration
  # for this tool for all Bourreaux, or nil if it doesn't exist.
  def global_tool_config
    @global_tool_config_cache ||= ToolConfig.where( :tool_id => self.id, :bourreau_id => nil ).first
  end

  # Returns the CbrainTask subclass associated with this tool.
  # This is basically a constantize() on the string attribute +cbrain_task_class_name+
  def cbrain_task_class
    cbrain_task_class_name.constantize
  end

  # Overloading assignment operator to accept arrays and strings for application_tag
  def application_tags=(val)
    array = val.is_a?(String) ? val.split(',') : val
    clean = (array.presence || []).select(&:present?).map(&:strip).uniq.sort # clean up
    write_attribute(:application_tags, clean.join(','))
  end

  # Oveloading the getter method to return current tags,
  # in an array by default or if :string is passed as
  # an argument the return type will be of class String
  def application_tags(return_class = :string)
    get_tag_attribute(:application_tags, return_class)
  end

  # Returns package_name tags associated with a tool
  def application_package_name(return_class = :string)
    get_tag_attribute(:application_package_name, return_class)
  end

  # Returns application_type tags associated with a tool
  def application_type(return_class = :string)
    get_tag_attribute(:application_type, return_class)
  end

  # Returns all tags associated with a tool, as an array
  def get_all_tags
    application_type(:array) + application_package_name(:array) + application_tags(:array)
  end

  private

  def url_present? #:nodoc:
    url.present?
  end

  # Reads one of the tag attributes, parses it and returns
  # a clean version of the content
  def get_tag_attribute(attribute_name, return_class) #:nodoc:
    tags_s = read_attribute(attribute_name).presence || ""
    tags_a = tags_s.split(',').select(&:present?).map(&:strip).uniq.sort # clean up
    return tags_a           if return_class == :array
    return tags_a.join(',') #                  :string
  end

  def set_default_attributes #:nodoc:
    self.select_menu_text ||= "Launch #{self.name}"
    self.description      ||= "#{self.name}"
  end

end
