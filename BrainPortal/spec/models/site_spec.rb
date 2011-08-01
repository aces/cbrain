#
# CBRAIN Project
#
# Site spec
#
# Original author: Nicolas Kassis
#
# $Id$
#


require 'spec_helper'

describe Site do 
  before(:each) do 
    @site         = Factory.create(:site)
    @site_manager = Factory.create(:user, :site => @site, :role => "site_manager")
    @site_user    = Factory.create(:user, :site => @site, :role => "user")
    @site.save
  end
  
  it "should save with valid attributes" do
    @site.save.should be(true)
  end
  
  it "should not save without a name" do
    @site.name = nil
    @site.save.should  be(false)
  end
  
  it "should return the array of managers whened asked" do
    @site.managers.should == [@site_manager]
  end
  
  it "should set new managers on save" do
    @site_user.role = "site_manager"
    @site_user.save
    @site.managers.include?(@site_user).should be(true)
  end
    
end
