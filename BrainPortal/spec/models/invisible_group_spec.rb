require 'spec_helper'

describe InvisibleGroup do
  let(:current_user) {Factory.create(:user)}
  
  describe "#can_be_edited_by?" do
    it "should allow edit access to admin user" do
      group = Factory.create(:invisible_group)
      user  = Factory.create(:user, :role => "admin")
      group.can_be_edited_by?(user).should be_true
    end
    
    it "should not allow edit access to non admin user" do
      group = Factory.create(:invisible_group)
      group.can_be_edited_by?(current_user).should be_false
    end
  end
  
  describe "#can_be_accessed_by?" do
    it "should allow access to admin user" do
      group = Factory.create(:invisible_group)
      user  = Factory.create(:user, :role => "admin")
      group.can_be_accessed_by?(user).should be_true
    end
    
    it "should not allow access to non admin user" do
      group = Factory.create(:invisible_group)
      group.can_be_accessed_by?(current_user).should be_false
    end
  end
  
end