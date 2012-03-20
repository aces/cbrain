
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

require 'spec_helper'

describe ResourceAccess do
  let(:normal_user) { Factory.create(:normal_user) }
  let(:site_manager) { Factory.create(:site_manager) }
  let(:admin) { Factory.create(:admin_user) }
  let(:free_resource)  { Factory.create(:data_provider) }
  let(:group_resource) { Factory.create(:data_provider, :group => user.groups.last) }
  let(:site_resource)  { Factory.create(:data_provider, :user => Factory.create(:normal_user, :site => user.site)) }
  let(:owned_resource) { Factory.create(:data_provider, :user => user) }
  
  
  describe "#can_be_accessed_by?" do
    describe "for admins" do
      let(:user) { admin }
            
      it "should give access to owned resource" do
        owned_resource.can_be_accessed_by?(admin).should be_true
      end
      it "should give access to site-associated resource" do
        site_resource.can_be_accessed_by?(admin).should be_true
      end
      it "should give access to group-associated resource" do
        group_resource.can_be_accessed_by?(admin).should be_true
      end
      it "should give access to non-associated resource" do
        free_resource.can_be_accessed_by?(admin).should be_true
      end
    end
    describe "for site managers" do
      let(:user) { site_manager }
      
      it "should give access to owned resource" do
        owned_resource.can_be_accessed_by?(site_manager).should be_true
      end
      it "should give access to site-associated resource" do
        site_resource.can_be_accessed_by?(site_manager).should be_true
      end
      it "should give access to group-associated resource" do
        group_resource.can_be_accessed_by?(site_manager).should be_true
      end
      it "should not give access to non-associated resource" do
        free_resource.can_be_accessed_by?(site_manager).should be_false
      end
    end
    describe "for regular users" do    
      let(:user) { normal_user }  
      
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
      let(:user) { admin }      
      it "should give access to owned resource" do
        owned_resource.has_owner_access?(admin).should be_true
      end
      it "should give access to site-associated resource" do
        site_resource.has_owner_access?(admin).should be_true
      end
      it "should give access to group-associated resource" do
        group_resource.has_owner_access?(admin).should be_true
      end
      it "should give access to non-associated resource" do
        free_resource.has_owner_access?(admin).should be_true
      end
    end
    describe "for site managers" do 
      let(:user) { site_manager }   
        
      it "should give access to owned resource" do
        owned_resource.has_owner_access?(site_manager).should be_true
      end
      it "should give access to site-associated and group-associated resource" do
        site_resource.group.site_id = site_resource.user.site_id
        site_resource.has_owner_access?(site_manager).should be_true
      end
      it "should not give access to site-associated resource" do
        site_resource.has_owner_access?(site_manager).should be_false
      end
      it "should not give access to group-associated resource" do
        group_resource.has_owner_access?(site_manager).should be_false
      end
      it "should not give access to non-associated resource" do
        free_resource.has_owner_access?(site_manager).should be_false
      end
    end
    describe "for regular users" do
      let(:user) { normal_user }  
      
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
    describe "for admins" do
      let(:user) { admin }  
      it "should return all resources for admins" do
        free_resource
        group_resource
        site_resource
        owned_resource
        DataProvider.find_all_accessible_by_user(admin).sort_by(&:id).should == [free_resource, group_resource, site_resource, owned_resource].sort_by(&:id)
      end
    end
    
    describe "for site managers" do
      let(:user) { site_manager }  
      it "should return owned, group and site-associated resources for site managers" do
        free_resource
        group_resource
        site_resource
        owned_resource
        DataProvider.find_all_accessible_by_user(site_manager).sort_by(&:id).should =~ [group_resource, site_resource, owned_resource].sort_by(&:id)
      end
    end
    
    describe "for regular users" do
      let(:user) { normal_user }  
      it "should return owned and group-associated resources for regular users" do
        free_resource
        group_resource
        site_resource
        owned_resource
        DataProvider.find_all_accessible_by_user(user).sort_by(&:id).should =~ [group_resource, owned_resource].sort_by(&:id)
      end
    end
    
  end
  
  describe "#find_accessible_by_user" do
    describe "for admins" do      
      let(:user) { admin }
      
      it "should find owned resources" do
        DataProvider.find_accessible_by_user(owned_resource.id, admin).should == owned_resource
      end
      it "should find site-associated resources" do
        DataProvider.find_accessible_by_user(site_resource.id, admin).should == site_resource
      end
      it "should find group-associated resources" do
        DataProvider.find_accessible_by_user(group_resource.id, admin).should == group_resource
      end
      it "should find non-associated resources" do
        DataProvider.find_accessible_by_user(free_resource.id, admin).should == free_resource
      end
    end
    describe "for site managers" do      
      let(:user) { site_manager }
      
      it "should find owned resources" do
        DataProvider.find_accessible_by_user(owned_resource.id, site_manager).should == owned_resource
      end
      it "should find site-associated resources" do
        DataProvider.find_accessible_by_user(site_resource.id, site_manager).should == site_resource
      end
      it "should find group-associated resources" do
        DataProvider.find_accessible_by_user(group_resource.id, site_manager).should == group_resource
      end
      it "should raise ActiveRecord::RecordNotFound when used to find non-associated resources" do
        lambda{DataProvider.find_accessible_by_user(free_resource.id, site_manager)}.should raise_error(ActiveRecord::RecordNotFound)
      end
    end
    describe "for users" do    
      let(:user) { normal_user }  
        
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

