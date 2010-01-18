require 'spec_helper'

describe Userfile do
  
  before(:each) do 
    @userfile = Factory.build(:userfile)
  end
  
  it "should be valid with valid attributes" do
    @userfile.valid?.should be true
  end
  
  it "should require a name" do
    @userfile.name = nil
    @userfile.valid?.should be false
  end
  
  it "should require a user" do
    @userfile.user = nil
    @userfile.valid?.should be false
  end
  
  it "should require a group" do
    @userfile.group = nil
    @userfile.valid?.should be false
  end
  
  it "should require that the user has no other files with the same name in the same data_provider" do
    @userfile.name = "abc"
    @userfile.save
    bad_file=Factory.build( :userfile, :name => "abc",
                                       :user => @userfile.user, 
                                       :data_provider => @userfile.data_provider )
    bad_file.valid?.should be false
  end
  
  it "should return the users site when site is called" do
    @userfile.save
    @userfile.site.should == @userfile.user.site
  end
  
  it "should return unknown for the format_size when size is blank" do
    @userfile.size = nil
    @userfile.format_size.should match("unknown")
  end
  
  it "should return GB for format_size when the size is over 1GB" do
    @userfile.size = 1000000000
    @userfile.format_size.should match("1.0 GB")
  end
  
end