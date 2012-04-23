
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

# This model represents a tool's configuration prefix.
# Unlike other models, the set of ToolConfigs is not
# arbitrary. They fit in three categories:
#
#   * A single tool config object represents the initialization
#     needed by a particular tool on all bourreaux; it
#     has a tool_id and no bourreau_id
#   * A single tool config object represents the initialization
#     needed by a particular bourreau for all tools; it
#     has a bourreau_id and no tool_id
#   * A set of 'versioning' tool config objects have both
#     a tool_id and a bourreau_id; they represent all
#     available versions of a tool on a particular bourreau.
#
class ToolConfig < ActiveRecord::Base

  Revision_info=CbrainFileRevision[__FILE__]

  serialize      :env_array

  belongs_to     :bourreau     # can be nil; it means it applies to all bourreaux
  belongs_to     :tool         # can be nil; it means it applies to all tools
  has_many       :cbrain_tasks
  belongs_to     :group        # can be nil; means 'everyone' in that case.

  validate       :presence_of_description # only when both tool_id and bourreau_id are defined

  scope          :global_for_tools     , where( { :bourreau_id => nil } )
  scope          :global_for_bourreaux , where( { :tool_id => nil } )
  scope          :specific_versions    , where( "bourreau_id is not null and tool_id is not null" )

  # CBRAIN extension
  force_text_attribute_encoding 'UTF-8', :description

  # A description is needed only when the tool config describes
  # a precise version of a tool (for both the tool and the bourreau).
  # There are more general tool configs that don't need a description.
  def presence_of_description #:nodoc: validation callback
    self.errors.add(:description,"cannot be blank.") if self.description.blank? && self.tool_id && self.bourreau_id
    true
  end

  # To make it somewhat compatible with the ResourceAccess module,
  # here's this model's own method for checking if it's visible to a user.
  def can_be_accessed_by?(user)
    return false unless self.group.can_be_accessed_by?(user)
    return false unless self.bourreau_and_tool_can_be_accessed_by?(user) 
    true
  end

  def self.find_all_accessible_by_user(user)
    if user.has_role?(:admin_user)
      ToolConfig.specific_versions
    else
      gids = user.group_ids
      bids = Bourreau.find_all_accessible_by_user(user).raw_first_column("remote_resources.id")
      tids = Tool.find_all_accessible_by_user(user).raw_first_column("tools.id")
      ToolConfig.specific_versions.where(:group_id => gids, :bourreau_id => bids, :tool_id => tids)
    end
  end

  # Returns true if both the bourreau and the tool associated
  # with the tool_config are defined and can be accessed by the user.
  def bourreau_and_tool_can_be_accessed_by?(user)
    self.bourreau && self.bourreau.can_be_accessed_by?(user) &&
    self.tool     && self.tool.can_be_accessed_by?(user)
  end

  # Returns the first line of the description. This is used
  # to represent the 'name' of the version.
  def short_description
    description = self.description || ""
    raise "Internal error: can't parse description!?!" unless description =~ /^(.+\n?)/ # the . doesn't match \n
    header = Regexp.last_match[1].strip
    header
  end

  # Sets in the current Ruby process all the environment variables
  # defined in the object. If +use_extended+ is true, the
  # set of variables provided by +extended_environement+ will be
  # applied instead.
  def apply_environment(use_extended = false)
    env   = (use_extended ? self.extended_environment : self.env_array) || []
    saved = ENV.to_hash
    env.each do |name,val|
      if val =~ /\$/
        #puts_green "THROUGH BASH: #{name} => #{val}" # debug
        newval = `bash -c 'echo \"#{val.strip}\"'`.strip  # this is quite inefficient, but how else to do it?
        #puts_green "RESULT:     : #{name} => #{newval}" # debug
      else
        #puts_green "DIRECT      : #{name} => #{val}" # debug
        newval = val
      end
      ENV[name.to_s]=newval.to_s
    end
    return yield
  ensure
    #(ENV.keys - saved.keys).each { |spurious| ENV.delete(spurious.to_s); puts_red "SPURIOUS: #{spurious}" } # debug
    #saved.each { |k,v| puts_cyan "RESTORED: #{ENV[k]=v.to_s}" unless ENV[k] == v } # debug
    (ENV.keys - saved.keys).each { |spurious| ENV.delete(spurious.to_s) }
    saved.each { |k,v| ENV[k]=v.to_s unless ENV[k] == v }
  end

  # Returns the set of environment variables as stored in
  # the object, plus a few artificial ones for CBRAIN usage.
  #
  #  CBRAIN_GLOBAL_TOOL_CONFIG_ID     : set to self.id if self represents a TOOL's global config
  #  CBRAIN_GLOBAL_BOURREAU_CONFIG_ID : set to self.id if self represents a BOURREAU's global config
  #  CBRAIN_TOOL_CONFIG_ID            : set to self.id
  def extended_environment
    env = (self.env_array || []).dup
    if self.id.present?
      env << [ "CBRAIN_GLOBAL_TOOL_CONFIG_ID",     self.id.to_s ] if self.bourreau_id.blank?
      env << [ "CBRAIN_GLOBAL_BOURREAU_CONFIG_ID", self.id.to_s ] if self.tool_id.blank?
      env << [ "CBRAIN_TOOL_CONFIG_ID",            self.id.to_s ] if ! self.tool_id.blank? && ! self.bourreau_id.blank?
    end
    env
  end

  # Generates a partial BASH script that initializes environment
  # variables and is followed a the script prologue stored in the
  # object.
  def to_bash_prologue
    tool     = self.tool
    bourreau = self.bourreau
    group    = self.group

    script = <<-HEADER

#===================================================
# Configuration: # #{self.id}
# Tool:          #{tool     ? tool.name     : "ALL"}
# Bourreau:      #{bourreau ? bourreau.name : "ALL"}
# Group:         #{group    ? group.name    : "everyone"}
#===================================================

    HEADER

    if self.tool_id && self.bourreau_id
      desc = self.description || ""
      script += <<-DESC_HEADER
#---------------------------------------------------
# Description:#{desc.blank? ? " (NONE SUPPLIED)" : ""}
#---------------------------------------------------

      DESC_HEADER
      if ! desc.blank?
        desc.gsub!(/\r\n/,"\n")
        desc.gsub!(/\r/,"\n")
        desc_array = desc.split(/\n/).collect { |line| "# #{line}" }
        script += desc_array.join("\n") + "\n\n"
      end
    end

    env = self.env_array || []
    script += <<-ENV_HEADER
#---------------------------------------------------
# Environment variables:#{env.size == 0 ? " (NONE DEFINED)" : ""}
#---------------------------------------------------

    ENV_HEADER
    env.each do |name_val|
      name = name_val[0]
      val  = name_val[1]
      name.strip!
      #val.gsub!(/'/,"'\''")
      script += "export #{name}=\"#{val}\"\n"
    end
    script += "\n" if env.size > 0

    prologue = self.script_prologue || ""
    script += <<-SCRIPT_HEADER
#---------------------------------------------------
# Script Prologue:#{prologue.blank? ? " (NONE SUPPLIED)" : ""}
#---------------------------------------------------

    SCRIPT_HEADER
    prologue.gsub!(/\r\n/,"\n")
    prologue.gsub!(/\r/,"\n")
    prologue += "\n" unless prologue =~ /\n$/

    script += prologue

    script
  end

  # Returns true if the object has no environment variables
  # and its script is blank or only contains blank lines or
  # comments.
  def is_trivial?
    return false if (self.env_array || []).size > 0
    text = self.script_prologue
    return true if text.blank?
    text_array = text.split(/\n/).reject { |line| line =~ /^\s*#|^\s*$/ }
    return true if text_array.size == 0
    false
  end

end
