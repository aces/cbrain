
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

describe Group do
  let(:group) {Factory.create(:system_group)}

  describe "#default_creator" do
    it "should set creator to admin if not set" do
      admin_user_id = User.admin.id
      new_group = Factory.create(:system_group, :creator_id => nil)
      new_group.creator_id.should == admin_user_id
    end
    it "should  set creator to admin even if already set" do
      admin_user_id = User.admin.id
      new_user_id = Factory.create(:user).id
      new_group = Factory.create(:system_group, :creator_id => new_user_id)
      new_group.creator_id.should == admin_user_id
    end
  end
end

