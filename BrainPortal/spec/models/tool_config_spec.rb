
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

require 'rails_helper'

describe ToolConfig do
  let(:tool_config) {create(:tool_config)}

  describe "#can_be_accessed_by?" do
    let(:user)              { create(:admin_user) }
    let(:group)             { create(:group, :users => [user]) }
    let(:group_tool_config) { create(:tool_config, :group => group) }
    let(:no_b_tool_config)  { create(:tool_config, :bourreau => nil) }
    let(:no_t_tool_config)  { create(:tool_config, :tool => nil) }

    it "should allow admin user to access a tool config even if they don't belong to its group" do
      expect(tool_config.can_be_accessed_by?(user)).to be_truthy
    end

    it "should not allow non-admin user to access a tool config if they don't belong to its group" do
      expect(tool_config.can_be_accessed_by?(create(:normal_user))).to be_falsey
    end

    it "should not allow user to access a tool config if the bourreau is not set" do
      expect(no_b_tool_config.can_be_accessed_by?(user)).to be_falsey
    end

    it "should not allow user to acces a tool config if the tool is not set" do
      expect(no_t_tool_config.can_be_accessed_by?(user)).to be_falsey
    end

    it "should allow non-admin user to access a tool config to which it is" do
      user.reload
      expect(group_tool_config.can_be_accessed_by?(user)).to be_truthy
    end
  end

  describe "#bourreau_and_tool_can_be_accessed_by?" do

    let(:bourreau) { double("bourreau", :can_be_accessed_by? => true) }
    let(:tool)     { double("tool",     :can_be_accessed_by? => true) }
    let(:user)     { double("user") }

    before(:each) do
      allow(tool_config).to receive(:bourreau).and_return(bourreau)
      allow(tool_config).to receive(:tool).and_return(tool)
    end

    it "should return true if both the bourreau and tool are accessible to the user" do
      expect(tool_config.bourreau_and_tool_can_be_accessed_by?(user)).to be_truthy
    end

    it "should return false if the bourreau is unset" do
      allow(tool_config).to receive(:bourreau).and_return(nil)
      expect(tool_config.bourreau_and_tool_can_be_accessed_by?(user)).to be_falsey
    end

    it "should return false if the tool is unset" do
      allow(tool_config).to receive(:tool).and_return(nil)
      expect(tool_config.bourreau_and_tool_can_be_accessed_by?(user)).to be_falsey
    end

    it "should return false if the bourreau is unaccessible" do
      allow(bourreau).to receive(:can_be_accessed_by?).and_return(false)
      expect(tool_config.bourreau_and_tool_can_be_accessed_by?(user)).to be_falsey
    end

    it "should return false if the tool is unaccessible" do
      allow(tool).to receive(:can_be_accessed_by?).and_return(false)
      expect(tool_config.bourreau_and_tool_can_be_accessed_by?(user)).to be_falsey
    end

  end

  describe "#short_description" do
    it "should return first line of description" do
      first_line  = "desc1_part1"
      second_line = "desc1_part2"
      tool_config.description = "#{first_line}\n#{second_line}"
      expect(tool_config.short_description).to eq(first_line)
    end
  end

  describe "#apply_environment" do

    it "should add env_array to ENV if use_extend is false" do
      increase = tool_config.env_array ? tool_config.env_array.size : 0
      expect do
        tool_config.apply_environment {}
      end.to change{ ENV.size }.by(increase)
    end

    it "should add extended_environment to ENV if use_extend is true" do
      tool_config.extended_environment ? tool_config.extended_environment.size : 0
      tool_config.apply_environment(true) { expect(ENV.keys).to include(tool_config.extended_environment.first.first)}
    end
  end

  describe "#extended_environment" do

    it "should add CBRAIN_GLOBAL_TOOL_CONFIG_ID entry to env if only bourreau_id is blank" do
      tool_config.bourreau_id  = nil
      tool_config.tool_id      = 1
      expect(tool_config.extended_environment).to include([ "CBRAIN_GLOBAL_TOOL_CONFIG_ID", tool_config.id.to_s ])
    end

    it "should add CBRAIN_GLOBAL_BOURREAU_CONFIG_ID to env if only tool_id is blank" do
      tool_config.bourreau_id  = 1
      tool_config.tool_id      = nil
      expect(tool_config.extended_environment).to include([ "CBRAIN_GLOBAL_BOURREAU_CONFIG_ID", tool_config.id.to_s ])
    end

    it "should add CBRAIN_TOOL_CONFIG_ID and CBRAIN_GLOBAL_BOURREAU_CONFIG_ID entry if bourreau_id and tool_id are blank" do
      tool_config.bourreau_id = nil
      tool_config.tool_id     = nil
      expect(tool_config.extended_environment).to include([ "CBRAIN_GLOBAL_TOOL_CONFIG_ID", tool_config.id.to_s ],[ "CBRAIN_GLOBAL_BOURREAU_CONFIG_ID", tool_config.id.to_s ])
    end

    it "should add CBRAIN_TOOL_CONFIG_ID entry if bourreau_id and tool_id are not blank" do
      tool_config.bourreau_id = 1
      tool_config.tool_id     = 1
      expect(tool_config.extended_environment).to include([ "CBRAIN_TOOL_CONFIG_ID", tool_config.id.to_s ])
    end

    it "should add CBRAIN_TC_VERSION_NAME entry if version_name are not blank" do
      expect(tool_config.extended_environment).to include([ "CBRAIN_TC_VERSION_NAME", tool_config.version_name ])
    end

    it "should not add CBRAIN_TC_VERSION_NAME entry if version_name are blank" do
      tool_config.version_name = nil
      expect(tool_config.extended_environment).not_to include([ "CBRAIN_TC_VERSION_NAME", tool_config.version_name ])
    end

  end

  describe "#to_bash_prologue" do

   let(:tool) {create(:tool, :cbrain_task_class_name => "CbrainTask::Diagnostics")}

   context "fill HEADER" do
      it "should print 'Configuration: tool_config.id'" do
        expect(tool_config.to_bash_prologue).to                    match(/Configuration\s?:\s+#\s+#{tool_config.id}/)
        expect(tool_config.to_bash_prologue(true)).to match(/Configuration\s?:\s+#\s+#{tool_config.id}/)
      end

      it "should print 'Tool: ALL' if specific tool is not defined"  do
        tool_config.tool = nil
        expect(tool_config.to_bash_prologue).to                    match(/Tool\s?:\s+ALL/)
        expect(tool_config.to_bash_prologue(apptainer: true)).to match(/Tool\s?:\s+ALL/)
      end

      it "should print 'Tool: tool_config.tool.name' if specific tool is defined"  do
        tool_config.tool = tool
        expect(tool_config.to_bash_prologue).to match(/Tool\s?:\s+#{tool_config.tool.name}/)
      end

      it "should print 'Bourreau: ALL' if specific bourreau is not defined"  do
        tool_config.bourreau = nil
        expect(tool_config.to_bash_prologue).to match(/Bourreau\s?:\s+ALL/)
      end

      it "should print 'Bourreau: tool_config.bourreau.name' if specific bourreau is defined"  do
        expect(tool_config.to_bash_prologue).to match(/Bourreau\s?:\s+#{tool_config.bourreau.name}/)
      end

      it "should print 'Group: everyone' if specific group is not defined"  do
        tool_config.group = nil
        expect(tool_config.to_bash_prologue).to match(/Group\s?:\s+everyone/)
      end

      it "should print 'Group: tool_config.group.name' if specific group is defined"  do
        expect(tool_config.to_bash_prologue).to match(/Group\s?:\s+#{tool_config.group.name}/)
      end
    end

    context "fill DESC" do
      it "should print 'Description: (NONE SUPPLIED)' if description is blank" do
        tool_config.description = nil
        tool_config.tool        = tool
        expect(tool_config.to_bash_prologue).to      match(/Description\s?:\s+\(NONE SUPPLIED\)/)
        expect(tool_config.to_bash_prologue true).to match(/Description\s?:\s+\(NONE SUPPLIED\)/)
      end

      it "should print 'Description: tool_config.description' if description is blank" do
        tool_config.tool        = tool
        expect(tool_config.to_bash_prologue).to      match(/Description\s?:\n\#\-+\n\n\#\s+#{tool_config.description}/)
        expect(tool_config.to_bash_prologue true).to match(/Description\s?:\n\#\-+\n\n\#\s+#{tool_config.description}/)
      end
    end

    context "fill ENV" do
      it "should print 'Environment variables: (NONE SUPPLIED)' if env is empty" do
        expect(tool_config.to_bash_prologue).to match(/Environment variables\s?:\s+\(NONE DEFINED\)/)
      end

      it "should print 'Environment variables: export name1=\"value1\".... if env is not empty" do
        tool_config.env_array = [["name1", "value1"],["name2","value2"]]

        script = ""
        tool_config.env_array.each do |name_val|
          name = name_val[0]
          val  = name_val[1]
          name.strip!
          script += "export #{name}=\\\"#{val}\\\"\\n"
        end

        expect(tool_config.to_bash_prologue).to match(/Environment variables\s?:\n\#\-+\n\n#{script}/)
      end
      it "should not print 'Environment variables: export APPTAINERENV_name1=\"value1\".... if config has no singularity" do
        tool_config.env_array = [["name1", "value1"],["name2","value2"]]
        expect(tool_config.to_bash_prologue).not_to match(/(SINGULARITYENV|APPTAINERENV)/)
      end
      it "should print 'export APPTAINERENV_name1=\"value1\".... if env is not empty and config uses singularity" do
        tool_config.env_array = [["name1", "value1"],["name2","value2"]]

        script = ""
        tool_config.env_array.each do |name_val|
          name = "APPTAINERENV_" + name_val[0].strip
          val  = name_val[1]
          script += "export #{name}=\\\"#{val}\\\"\\n"
        end

        expect(tool_config.to_bash_prologue true).to match(/#{script}/)
      end
    end

    context "fill SCRIPT" do
      it "should print 'Script Prologue: (NONE SUPPLIED)' if script_prologue is blank" do
        expect(tool_config.to_bash_prologue).to match(/Script Prologue\s?:\s+\(NONE SUPPLIED\)/)
      end

      it "should print 'Script Prologue: tool_config.script_prologue' if script_prologue is not blank" do
        tool_config.script_prologue = "script_prologue"
        expect(tool_config.to_bash_prologue).to match(/Script Prologue\s?:\n\#\-+\n\n#{tool_config.script_prologue}/)
      end
    end
  end

  describe "#is_trivial?" do

    it "should return false if object has environment variables in env_array" do
      tool_config.env_array = ["env1"]
      expect(tool_config.is_trivial?).to be_falsey
    end

    it "should return true if script_prologue is blank" do
      tool_config.script_prologue = nil
      expect(tool_config.is_trivial?).to be_truthy
    end

    it "should return true if script_prologue contain only comments" do
      tool_config.script_prologue = "#prologue11\n#prologue2"
      expect(tool_config.is_trivial?).to be_truthy
    end

    it "should return false if script_prologue is not blank and don't contain only comments" do
      tool_config.script_prologue = "prologue1"
      expect(tool_config.is_trivial?).to be_falsey
    end
  end

end
