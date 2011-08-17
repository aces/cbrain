require 'spec_helper'

describe Group do
  let(:group) {Factory.create(:group)}
  let(:user) {mock_model(User)}
  
  describe "#everyone" do
    it "should provide me with access to 'everyone' group" do
      Group.everyone.name.should == "everyone"
      Group.everyone.should be_a SystemGroup
    end
  end
  
  describe "#pretty_category_name" do    
    it "should convert the suffix 'Group' of a class name to 'Project'" do
      group.stub!(:class).and_return(SystemGroup)
      group.pretty_category_name(user).should == "System Project"
    end
  end
  
  describe "#reassign_models_to_owner_group" do
    it "should reassign associated resources when destroyed" do
      tag = Factory.create(:tag, :group => group)
      user = tag.user
      group.destroy
      tag.reload
      tag.group.should == user.own_group
    end
  end
  
  describe "#own_group" do
    it "should return itself as own group" do
      group.own_group.should == group
    end
  end
  
  describe "#can_be_edited_by?" do
    it "should not allow edit access" do
      group.can_be_edited_by?(user).should be_false
    end
  end
  
  describe "#can_be_accessed_by?" do
    let(:current_user) { Factory.create(:user) }
    
    it "should allow admin access to any group" do
      current_user.role = "admin"
      group.can_be_accessed_by?(current_user).should be_true
    end
    
    it "should not allow non-admin access to a group to which the user does not belong" do
      group.can_be_accessed_by?(current_user).should be_false
    end
    
    it "should allow non-admin access to a group to which the user does belong" do
      group.users << current_user
      current_user.reload
      group.can_be_accessed_by?(current_user).should be_true
    end
  end
  
  describe "#default_creator" do
    it "should set creator to admin id if not set" do
      admin_user_id = User.find_by_login("admin").id
      new_group = Factory.create(:group, :creator_id => nil)
      new_group.creator_id.should == admin_user_id
    end
    it "should not set creator if already set" do
      new_user_id = Factory.create(:user).id
      new_group = Factory.create(:group, :creator_id => new_user_id)
      new_group.creator_id.should == new_user_id
    end
  end
end
