#
# CBRAIN Project
#
# User spec
#
# Original author: Nicolas Kassis
#
# $Id$
#

require 'spec_helper'

describe User do
  
  before(:each) do 
    @user = Factory.build(:user)
  end
  
  it "should save with valid attributes" do
    @user.save
  end
  
  it "should not save without a login" do
    @user.login = nil
    @user.save.should == false
  end
  
  it "should not save without a full_name" do
    @user.full_name = nil
    @user.save.should == false
  end
  
  it "should not save without an email" do
    @user.email = nil
    @user.save.should == false
  end
  
  it "should not save without a role" do 
    @user.role = nil
    @user.save.should == false
  end
  
  it "should not save without a password" do
    @user.password = nil
    @user.save.should == false
  end
  
  it "should not save without a password_confirmation" do
    @user.password_confirmation = nil 
    @user.save.should == false
  end
  
  it "should not save without a password and password_confirmation that match" do
    @user.password = "aksdhflaksjhdfl"
    @user.password_confirmation = "ajsdfkl;ajsdflkja9j"
    @user.save.should == false
  end
  
  it "should not accept a password shorter than 4 char" do
    @user.password = "abc"
    @user.password_confirmation = "abc"
    @user.save.should == false
  end
  
  it "should not accept a login shorter than 3 char" do
    @user.login = "ab"
    @user.save.should == false
  end
  
  it "should not accept a email address shorter than 3 char" do
    @user.email = "a@"
    @user.save.should be(false)
  end
  
  it "should check that login is unique" do
    Factory.create(:user, :login => "Abcdef")
    bad_login=Factory.build(:user, :login => "Abcdef")
    bad_login.save.should be(false)
  end
  
  it "should check that login is unique even case wise" do
    Factory.create(:user, :login => "Abcdef")
    bad_login=Factory.build(:user, :login => "abcdef")
    bad_login.save.should be(false)
  end
  
  it "should check that a user is a site_manager on save" do
    @user.role = "site_manager"
    @user.save
    @user.site.managers.include?(@user).should be(true)
  end
  
  it "should prevent me from using the login everyone" do
    @user.login = "everyone"
    @user.valid?.should  be(false)
  end
  
  it "should prevent me from using another system group name as login name" do
    Factory.create(:system_group, :name => "my_name_is_group")
    @user.login = "my_name_is_group"
    @user.should_not be_valid
  end
  
  it "should prevent me from changing my login name" do
    @user.save
    @user.login = "not_my_orginal_login"
    @user.save.should  be(false)
  end
  
  it "should create a new UserGroup with my login on create" do
    @user.login = "this_group_should_exit"
    @user.save
    new_group=UserGroup.find_by_name("this_group_should_exit")
    new_group.instance_of?(UserGroup).should be(true)
  end
  
  it "should add me to the everyone group" do
    @user.save
    @user.groups.include?(Group.everyone).should be(true)
  end
  
  it "should add me to the site group" do
    @user.site = Factory.create(:site, :name => "I_should_be_part_of_this_site_group")
    @user.save
    @user.groups.include?(SystemGroup.find_by_name("I_should_be_part_of_this_site_group")).should be(true)
  end
end
