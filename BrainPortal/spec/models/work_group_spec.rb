
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

describe WorkGroup do
  let(:current_user) {Factory.create(:normal_user)}
  let(:other_user) {Factory.create(:normal_user)}
  
  describe "#pretty_category_name" do
    it "should give pretty name 'My Work Project' if it belongs to the current user" do
      Factory.create(:work_group, :users => [current_user]).pretty_category_name(current_user).should == "My Work Project"
    end
    
    it "should give pretty name 'Personal Work Project of...' if it's a personal project belonging to someone other than the current user" do
      Factory.create(:work_group, :users => [other_user]).pretty_category_name(current_user).should == "Personal Work Project of #{other_user.full_name}"
    end
    
    it "should give pretty name 'Shared Work Project' if it contains more that one user" do
      Factory.create(:work_group, :users => [other_user, current_user]).pretty_category_name(current_user).should == "Shared Work Project"
    end
    
    it "should give pretty name 'Empty Work Project' if it contains no users" do
      Factory.create(:work_group, :users => []).pretty_category_name(current_user).should == "Empty Work Project"
    end
  end
  
  describe "#can_be_edited_by?" do
    it "should allow edit access to admin user" do
      group = Factory.create(:work_group)
      user  = Factory.create(:admin_user)
      group.can_be_edited_by?(user).should be_true
    end
    
    it "should allow edit access to site manager if group belongs to site" do
      site  = Factory.create(:site)
      group = Factory.create(:work_group, :site_id => site.id)
      user  = Factory.create(:site_manager, :site_id => site.id)
      group.can_be_edited_by?(user).should be_true
    end
    
    it "should not allow edit access to site manager if group does belong to site" do
      site  = Factory.create(:site)
      group = Factory.create(:work_group)
      user  = Factory.create(:site_manager, :site_id => site.id)
      group.can_be_edited_by?(user).should be_false
    end
    
    it "should allow edit access to user if they are the creator" do
      group = Factory.create(:work_group, :users => [current_user], :creator_id => current_user.id)
      group.can_be_edited_by?(current_user).should be_true
    end
    
    it "should not allow edit access to user if not in group" do
      group = Factory.create(:work_group)
      group.can_be_edited_by?(current_user).should be_false
    end
    
    it "should not allow edit access to user if not only user in group" do
      group = Factory.create(:work_group, :users => [current_user])
      group.can_be_edited_by?(current_user).should be_false
    end 
  end
  
end

