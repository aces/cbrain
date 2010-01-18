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
  
  #Testing the format_size method
  it "should return unknown for the format_size when size is blank" do
    @userfile.size = nil
    @userfile.format_size.should match("unknown")
  end
  
  it "should return GB for format_size when the size is over 1GB" do
    @userfile.size = 1000000000
    @userfile.format_size.should match("1.0 GB")
  end
  
  it "should return MB for format_size when the size is less than 1GB and more than 1MB" do
    @userfile.size = 100000000
    @userfile.format_size.should match("100.0 MB")
  end
  
  it "should return KB for the format_size when the size is less than 1MB and more than 1KB" do
    @userfile.size = 10000
    @userfile.format_size.should match("10.0 KB")
  end
  
  it "should return bytes for the format_size when the size is less than 1KB and more than 0" do
    @userfile.size = 10
    @userfile.format_size.should match("10 bytes")
  end
  
  #Testing the get_tags_for_user method
  it "should return no tags when user and files has no tags" do
    @userfile.get_tags_for_user(@userfile.user)
  end
  
  it "should return it's tags crossed with the user when get_tags_for_user(user) is called and the file has tags" do
    test_tag = Factory.create(:tag, :name => "test_tag", :user => @userfile.user)
    @userfile.tags << test_tag
    @userfile.get_tags_for_user(@userfile.user).include?(test_tag).should be true
  end
  
  it "should return no tags if the user has no tags in common with the userfile tags" do
     test_tag = Factory.create(:tag, :name => "test_tag")
     @userfile.tags << test_tag
     @userfile.get_tags_for_user(@userfile.user).include?(test_tag).should be false
   end
   
   it "should set new tags when I call set_tags_for_user with new tags" do
     test_tag = Factory.create(:tag, :user => @userfile.user)
     @userfile.set_tags_for_user(@userfile.user, [test_tag])
     @userfile.get_tags_for_user(@userfile.user).include?(test_tag).should be true
   end
    
   it "should not set new tags if not owned by user" do
      test_tag = Factory.create(:tag)
      @userfile.set_tags_for_user(@userfile.user, [test_tag])
      @userfile.tags.include?(test_tag).should be false
  end

  it "s"
    
end