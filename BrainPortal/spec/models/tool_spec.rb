#
# CBRAIN Project
#
# Tool spec
#
# Original author: Nicolas Kassis
#
# $Id$
#

require 'spec_helper'

describe Tool do
  before(:each) do
    @tool = Factory.build(:tool)
  end
  
  it "should create a tool with valid attributes given" do
    @tool.save
  end
  
  it "should require a name" do
    @tool.name = nil
    @tool.save.should be false
  end
  
  it "should require a unique name" do
    @tool.name = "A tool"
    @tool.save
    bad_tool = Factory.build(:tool, :name => "A tool")
    bad_tool.valid?.should be false
  end
  
  it "should require a user" do
    @tool.user = nil
    @tool.valid?.should be false
  end
  
  it "should require a group" do
    @tool.group = nil
    @tool.valid?.should be false
  end
  
  it "should require a category" do
    @tool.category = nil
    @tool.valid?.should be false
  end
  
  it "should create a description if none is present" do
    @tool.description = nil
    @tool.valid?.should be true
  end
  
  it "should keep description if present" do
     @tool.description = "keep this"
     @tool.save
     @tool.description.should == "keep this"
   end
  
  it "should create a select_menu_text if none is present" do
    @tool.select_menu_text = nil
    @tool.valid?.should be true
  end
  
  it "should keep select_menu_text if present" do
    @tool.select_menu_text = "keep this"
    @tool.save
    @tool.select_menu_text.should == "keep this"
  end
  
  it "should validate that category is in the Categories constant" do
    @tool.category = "this is wrong"
    @tool.valid?.should be false
  end
  
  #Should it check for a valid category?
  
end
