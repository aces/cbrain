
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

require 'spec_helper'

describe Tool do
  let(:tool) {Factory.build(:tool)}

  it "should keep description if present" do
   tool.description = "keep this"
   tool.save
   tool.description.should == "keep this"
  end
  
  it "should keep select_menu_text if present" do
    tool.select_menu_text = "keep this"
    tool.save
    tool.select_menu_text.should == "keep this"
  end
  
  it "should validate that category is in the Categories constant" do
    tool.category = "this is wrong"
    tool.should_not be_valid
  end
  
  describe "#bourreaux" do
    it "should return the list of bourreaux where this tool is installed" do
      tool_config = Factory.create(:tool_config, :tool => tool)
      tool.bourreaux.should =~ [tool_config.bourreau]
    end
  end

  describe "#global_tool_config" do
    it "should return the single ToolConfig that describes the configuration for this tool for all Bourreaux" do
      tool_config1 = Factory.create(:tool_config, :tool_id => tool.id, :bourreau_id => nil)
      tool.global_tool_config.should == tool_config1
    end
    it "should return nil if no single ToolConfig exist for this tool" do
      tool_config1 = Factory.create(:tool_config, :tool_id => tool.id)
      tool.global_tool_config.should == nil  
    end
  end
  
end

