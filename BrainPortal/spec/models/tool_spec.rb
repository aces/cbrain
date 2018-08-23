
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

describe Tool do
  let(:tool) do
    allow(File).to receive(:exists?).and_return(true)
    build(:tool)
  end


  it "should keep description if present" do
   tool.description = "keep this"
   tool.save
   expect(tool.description).to eq("keep this")
  end

  it "should be able assign license to a new tool" do
    tool.license_agreements = "keep_this"
    # needs underscore because spaces are not well supported, backend splits the string (which is default on whitespaces)
    expect(tool.license_agreements).to eq(["keep_this"])
  end

  it "should be able assign multiple license to a new tool" do
    tool.license_agreements = "keep_this\nkeep_that"
    expect(tool.license_agreements).to eq(["keep_that", "keep_this"])
  end

  it "should be able assign multiple license to a tool" do
    tool.license_agreements = "keep_this\nkeep_that"
    tool.save
    expect(tool.license_agreements).to eq(["keep_that", "keep_this"])
    tool.reload
    expect(tool.license_agreements).to eq(["keep_that", "keep_this"])
  end

  it "should be able able remove license from a tool" do
    tool.license_agreements = "keep_this"
    tool.license_agreements = ""
    expect(tool.license_agreements).to eq([])
    tool.save
    expect(tool.license_agreements).to eq([])
    tool.reload
    expect(tool.license_agreements).to eq([])
  end

  it "should keep license if present" do
    tool.license_agreements = "keep_this"
    expect(tool.license_agreements).to eq(["keep_this"])
    tool.save
    expect(tool.license_agreements).to eq(["keep_this"])
    tool.reload
    expect(tool.license_agreements).to eq(["keep_this"])
  end

  it "should keep singleton license list" do
    tool.license_agreements = ["keep_this"]
    expect(tool.license_agreements).to eq(["keep_this"])
    tool.save
    expect(tool.license_agreements).to eq(["keep_this"])
    tool.reload
    expect(tool.license_agreements).to eq(["keep_this"])
  end

  it "should change license" do
    tool.license_agreements = "keep_this"
    expect(tool.license_agreements).to eq(["keep_this"])
    tool.license_agreements = "keep_that"
    expect(tool.license_agreements).to eq(['keep_that'])
    tool.save
    expect(tool.license_agreements).to eq(["keep_that"])
    tool.reload
    expect(tool.license_agreements).to eq(["keep_that"])
  end

  it "should let change saved license after save" do
    tool.license_agreements = "keep_this"
    tool.save
    expect(tool.license_agreements).to eq(["keep_this"])
    tool.save
    tool.license_agreements = "keep_that"
    expect(tool.license_agreements).to eq(["keep_that"])
    tool.save
  end

  it "should invalidate incorrect license" do
    allow(File).to receive(:exists?).with("keep").and_return(false)
    allow(File).to receive(:exists?).with("this").and_return(false)
    tool.license_agreements = "keep this"
    expect(tool.valid?).to eq(false)
  end

  it "should invalidate incorrect license after save" do
    allow(File).to receive(:exists?).with("keep").and_return(false)
    allow(File).to receive(:exists?).with("this").and_return(false)
    tool.license_agreements = "keep this"
    tool.save
    expect(tool.valid?).to eq(false)
  end

  it "should validate license " do
    allow(File).to receive(:exists?).and_return(true)
    # File.stub(:exists?).and_return(true)
    tool.license_agreements = "keep_this"
    tool.save
    expect(tool.valid?).to eq(true)
  end

  it "should keep select_menu_text if present" do
    tool.select_menu_text = "keep this"
    tool.save
    expect(tool.select_menu_text).to eq("keep this")
  end

  it "should validate that category is in the Categories constant" do
    tool.category = "this is wrong"
    expect(tool).not_to be_valid
  end

  describe "#bourreaux" do
    it "should return the list of bourreaux where this tool is installed" do
      tool_config = create(:tool_config, :tool => tool)
      expect(tool.bourreaux).to match_array([tool_config.bourreau])
    end
  end

  describe "#global_tool_config" do
    it "should return the single ToolConfig that describes the configuration for this tool for all Bourreaux" do
      tool_config1 = create(:tool_config, :tool_id => tool.id, :bourreau_id => nil)
      expect(tool.global_tool_config).to eq(tool_config1)
    end
    it "should return nil if no single ToolConfig exist for this tool" do
      create(:tool_config, :tool_id => tool.id)
      expect(tool.global_tool_config).to eq(nil)
    end
  end

end

