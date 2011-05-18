require 'spec_helper'

describe Group do
  let(:current_user) {Factory.create(:user)}
  
  describe "#everyone" do
    it "should provide me with access to 'everyone' group" do
      Group.everyone.name.should == "everyone"
      Group.everyone.should be_is_a SystemGroup
    end
  end
  
  describe "#pretty_category_name" do    
    it "should give InvisibleGroup the pretty name 'Invisible Project'" do
      Factory.create(:invisible_group).pretty_category_name(current_user).should == "Invisible Project"
    end
    
    it "should give UserGroup the pretty name 'User Project'" do
      Factory.create(:user_group).pretty_category_name(current_user).should == "User Project"
    end
    
    it "should give SiteGroup the pretty name 'Site Project'" do
      Factory.create(:site_group).pretty_category_name(current_user).should == "Site Project"
    end
  end
  
  describe "#reassign_models_to_owner_group" do
    it "should reassign associated resources when destroyed" do
      group = Factory.create(:group)
      tag = Factory.create(:tag, :group => group)
      user = tag.user
      group.destroy
      tag.reload
      tag.group.should == user.own_group
    end
  end
  
  describe "#own_group" do
    it "should return itself as own group" do
      group = Factory.build(:group)
      group.own_group.should == group
    end
  end
  
  describe "#can_be_edited_by?" do
    it "should not allow edit access" do
      group = Factory.create(:group)
      group.can_be_edited_by?(current_user).should be_false
    end
  end
  
  describe "#can_be_accessed_by?" do
    it "should allow admin access to any group" do
      user = Factory.create(:user, :role => "admin")
      group = Factory.create(:group)
      group.can_be_accessed_by?(user).should be_true
    end
    
    it "should not allow non-admin access to a group to which the user does not belong" do
      group = Factory.create(:group)
      group.can_be_accessed_by?(current_user).should be_false
    end
    
    it "should allow non-admin access to a group to which the user does belong" do
      group = Factory.create(:group, :users => [current_user])
      current_user.reload
      group.can_be_accessed_by?(current_user).should be_true
    end
  end
  
end
