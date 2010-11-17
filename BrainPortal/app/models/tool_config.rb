
#
# CBRAIN Project
#
# Original author: Pierre Rioux
#
# $Id$
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

  Revision_info="$Id$"

  serialize      :env_array

  belongs_to     :bourreau     # can be nil; it means it applies to all bourreaux
  belongs_to     :tool         # can be nil; it means it applies to all tools
  has_many       :cbrain_tasks
  belongs_to     :group        # can be nil; means 'everyone' in that case.

  # Provides a default group_id (backward compatibility)
  def group #:nodoc:
    Group.find(self.group_id)
  end

  # Provides a default group_id (backward compatibility)
  def group_id #:nodoc:
    myid = self.read_attribute(:group_id)
    return myid if myid

    myid = Group.find_by_name('everyone').id
    self.write_attribute(:group_id, myid)
    myid
  end

  # Returns the first line of the description. This is used
  # to represent the 'name' of the version.
  def short_description
    description = self.description || ""
    raise "Internal error: can't parse description!?!" unless description =~ /^\s*(\S.*)\n?([\000-\277]*)$/
    header = Regexp.last_match[1].strip
    header
  end

  # Sets in the current Ruby process all the environment variables
  # defined in the object. If +use_extended+ is true, the
  # set of variables provided by +extended_environement+ will be
  # applied instead.
  def apply_environment(use_extended = false)
    env = (use_extended ? self.extended_environment : self.env_array) || []
    env.each do |name,val|
      ENV[name.to_s]=val.to_s
    end
    true
  end

  # Returns the set of environment variables as stored in
  # the object, plus a few artificial ones. See the code.
  def extended_environment
    env = (self.env_array || []).dup
    env << [ "CBRAIN_GLOBAL_TOOL_CONFIG_ID",     self.id.to_s ] if self.bourreau_id.blank?
    env << [ "CBRAIN_GLOBAL_BOURREAU_CONFIG_ID", self.id.to_s ] if self.tool_id.blank?
    env << [ "CBRAIN_TOOL_CONFIG_ID",            self.id.to_s ] if ! self.tool_id.blank? && ! self.bourreau_id.blank?
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
