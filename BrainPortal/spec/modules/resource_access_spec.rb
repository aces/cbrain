require 'spec_helper'

describe ResourceAccess do
  let(:user) { Factory.create(:user) }
  let(:free_resource)  { Factory.create(:data_provider) }
  let(:group_resource) { Factory.create(:data_provider, :group => user.groups.last) }
  let(:site_resource)  { Factory.create(:data_provider, :user => Factory.create(:user, :site => user.site)) }
  let(:owned_resource) { Factory.create(:data_provider, :user => user) }
  
  
  describe "#can_be_accessed_by?" do
    describe "for admins" do
      before(:each) {user.role = "admin"}
      
      it "should give access to owned resource" do
        owned_resource.can_be_accessed_by?(user).should be_true
      end
      it "should give access to site-associated resource" do
        site_resource.can_be_accessed_by?(user).should be_true
      end
      it "should give access to group-associated resource" do
        group_resource.can_be_accessed_by?(user).should be_true
      end
      it "should give access to non-associated resource" do
        free_resource.can_be_accessed_by?(user).should be_true
      end
    end
    describe "for site managers" do
      before(:each) {user.role = "site_manager"}
      
      it "should give access to owned resource" do
        owned_resource.can_be_accessed_by?(user).should be_true
      end
      it "should give access to site-associated resource" do
        site_resource.can_be_accessed_by?(user).should be_true
      end
      it "should give access to group-associated resource" do
        group_resource.can_be_accessed_by?(user).should be_true
      end
      it "should not give access to non-associated resource" do
        free_resource.can_be_accessed_by?(user).should be_false
      end
    end
    describe "for regular users" do
      before(:each) {user.role = "user"}
      
      it "should give access to owned resource" do
        owned_resource.can_be_accessed_by?(user).should be_true
      end
      it "should not give access to site-associated resource" do
        site_resource.can_be_accessed_by?(user).should be_false
      end
      it "should give access to group-associated resource" do
        group_resource.can_be_accessed_by?(user).should be_true
      end
      it "should not give access to non-associated resource" do
        free_resource.can_be_accessed_by?(user).should be_false
      end
    end
  end
  
  describe "#has_owner_access?" do
    describe "for admins" do
      before(:each) {user.role = "admin"}
      
      it "should give access to owned resource" do
        owned_resource.has_owner_access?(user).should be_true
      end
      it "should give access to site-associated resource" do
        site_resource.has_owner_access?(user).should be_true
      end
      it "should give access to group-associated resource" do
        group_resource.has_owner_access?(user).should be_true
      end
      it "should give access to non-associated resource" do
        free_resource.has_owner_access?(user).should be_true
      end
    end
    describe "for site managers" do
      before(:each) {user.role = "site_manager"}
      
      it "should give access to owned resource" do
        owned_resource.has_owner_access?(user).should be_true
      end
      it "should give access to site-associated and group-associated resource" do
        site_resource.group.site_id = site_resource.user.site_id
        site_resource.has_owner_access?(user).should be_true
      end
      it "should not give access to site-associated resource" do
        site_resource.has_owner_access?(user).should be_false
      end
      it "should not give access to group-associated resource" do
        group_resource.has_owner_access?(user).should be_false
      end
      it "should not give access to non-associated resource" do
        free_resource.has_owner_access?(user).should be_false
      end
    end
    describe "for regular users" do
      before(:each) {user.role = "user"}
      
      it "should give access to owned resource" do
        owned_resource.has_owner_access?(user).should be_true
      end
      it "should not give access to site-associated resource" do
        site_resource.has_owner_access?(user).should be_false
      end
      it "should not give access to group-associated resource" do
        group_resource.has_owner_access?(user).should be_false
      end
      it "should not give access to non-associated resource" do
        free_resource.has_owner_access?(user).should be_false
      end
    end
  end
   
  describe "#find_all_accessible_by_user" do
    before(:each) do
      free_resource
      group_resource
      site_resource
      owned_resource
    end
      
    it "should return all resources for admins" do
      user.role = "admin"
      DataProvider.find_all_accessible_by_user(user).sort_by(&:id).should == [free_resource, group_resource, site_resource, owned_resource].sort_by(&:id)
    end
    
    it "should return owned, group and site-associated resources for site managers" do
      user.role = "site_manager"
      DataProvider.find_all_accessible_by_user(user).sort_by(&:id).should =~ [group_resource, site_resource, owned_resource].sort_by(&:id)
    end
    
    it "should return owned and group-associated resources for regular users" do
      user.role = "user"
      DataProvider.find_all_accessible_by_user(user).sort_by(&:id).should =~ [group_resource, owned_resource].sort_by(&:id)
    end
  end
  
  describe "#find_accessible_by_user" do
    describe "for admins" do
      before(:each) {user.role = "admin"}
      
      it "should find owned resources" do
        DataProvider.find_accessible_by_user(owned_resource.id, user).should == owned_resource
      end
      it "should find site-associated resources" do
        DataProvider.find_accessible_by_user(site_resource.id, user).should == site_resource
      end
      it "should find group-associated resources" do
        DataProvider.find_accessible_by_user(group_resource.id, user).should == group_resource
      end
      it "should find non-associated resources" do
        DataProvider.find_accessible_by_user(free_resource.id, user).should == free_resource
      end
    end
    describe "for site managers" do
      before(:each) {user.role = "site_manager"}
      
      it "should find owned resources" do
        DataProvider.find_accessible_by_user(owned_resource.id, user).should == owned_resource
      end
      it "should find site-associated resources" do
        DataProvider.find_accessible_by_user(site_resource.id, user).should == site_resource
      end
      it "should find group-associated resources" do
        DataProvider.find_accessible_by_user(group_resource.id, user).should == group_resource
      end
      it "should rause ActiveRecord::RecordNotFound when used to find non-associated resources" do
        lambda{DataProvider.find_accessible_by_user(free_resource.id, user)}.should raise_error(ActiveRecord::RecordNotFound)
      end
    end
    describe "for users" do
      before(:each) {user.role = "user"}
      
      it "should find owned resources" do
        DataProvider.find_accessible_by_user(owned_resource.id, user).should == owned_resource
      end
      it "should rause ActiveRecord::RecordNotFound when used to find site-associated resources" do
        lambda{DataProvider.find_accessible_by_user(site_resource.id, user)}.should raise_error(ActiveRecord::RecordNotFound)
      end
      it "should find group-associated resources" do
        DataProvider.find_accessible_by_user(group_resource.id, user).should == group_resource
      end
      it "should rause ActiveRecord::RecordNotFound when used to find non-associated resources" do
        lambda{DataProvider.find_accessible_by_user(free_resource.id, user)}.should raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
