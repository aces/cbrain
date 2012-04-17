
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

describe InvisibleGroup do
  let(:current_user) {Factory.create(:normal_user)}
  
  describe "#can_be_edited_by?" do
    it "should allow edit access to admin user" do
      group = Factory.create(:invisible_group)
      user  = Factory.create(:admin_user)
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
      user  = Factory.create(:admin_user)
      group.can_be_accessed_by?(user).should be_true
    end
    
    it "should not allow access to non admin user" do
      group = Factory.create(:invisible_group)
      group.can_be_accessed_by?(current_user).should be_false
    end
  end
  
end

