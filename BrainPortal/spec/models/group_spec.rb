
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

require 'rails_helper'

describe Group do
  let(:group) { create(:group) }
  let(:user)  { mock_model(User) }

  describe "#everyone" do
    it "should provide me with access to 'everyone' group" do
      expect(Group.everyone.name).to eq("everyone")
      expect(Group.everyone).to be_a SystemGroup
    end
  end

  describe ".pretty_type" do
    it "should convert the suffix 'Group' of a class name to 'Project'" do
      #allow(group).to receive(:class).and_return(SystemGroup)
      expect(group.pretty_category_name(user)).to eq("Empty Work Project")
    end
  end

  describe "#reassign_models_to_owner_group" do
    it "should reassign associated resources when destroyed" do
      tag  = create(:tag, :group => group)
      user = tag.user
      group.destroy
      tag.reload
      expect(tag.group).to eq(user.own_group)
    end
  end

  describe "#own_group" do
    it "should return itself as own group" do
      expect(group.own_group).to eq(group)
    end
  end

  describe "#can_be_edited_by?" do
    it "should not allow edit access" do
      expect(Group.new.can_be_edited_by?(user)).to be_falsey
    end
  end

  describe "#can_be_accessed_by?" do
    let(:current_user) { create(:normal_user) }

    it "should allow admin access to any group" do
      admin_user = User.admin
      expect(group.can_be_accessed_by?(admin_user)).to be_truthy
    end

    it "should not allow non-admin access to a group to which the user does not belong" do
      expect(group.can_be_accessed_by?(current_user)).to be_falsey
    end

    it "should allow non-admin access to a group to which the user does belong" do
      group.users << current_user
      current_user.reload
      expect(group.can_be_accessed_by?(current_user)).to be_truthy
    end
  end

  describe "#default_creator" do
    it "should set creator to admin id if not set" do
      admin_user_id = User.find_by_login("admin").id
      new_group = create(:group, :creator_id => nil)
      expect(new_group.creator_id).to eq(admin_user_id)
    end
    it "should not set creator if already set" do
      new_user_id = create(:normal_user).id
      new_group = create(:group, :creator_id => new_user_id)
      expect(new_group.creator_id).to eq(new_user_id)
    end
  end
end

