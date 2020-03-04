
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

describe WorkGroup do
  let(:current_user) {create(:normal_user)}
  let(:other_user) {create(:normal_user)}

  describe "#pretty_category_name" do
    it "should give pretty name 'My Work Project' if it belongs to the current user" do
      expect(create(:work_group, :users => [current_user]).pretty_category_name(current_user)).to eq("My Work Project")
    end

    it "should give pretty name 'Personal Work Project of...' if it's a personal project belonging to someone other than the current user" do
      expect(create(:work_group, :users => [other_user]).pretty_category_name(current_user)).to eq("Personal Work Project of #{other_user.full_name}")
    end

    it "should give pretty name 'Shared Work Project' if it contains more that one user" do
      expect(create(:work_group, :users => [other_user, current_user]).pretty_category_name(current_user)).to eq("Shared Work Project")
    end

    it "should give pretty name 'Empty Work Project' if it contains no users" do
      expect(create(:work_group, :users => []).pretty_category_name(current_user)).to eq("Empty Work Project")
    end
  end

  describe "#can_be_edited_by?" do
    let!(:user_a)  { create(:normal_user, :login => "U_A" ) }
    let!(:group_a) { create(:work_group,  :name  => "G_A", :user_ids => [user_a.id], :editor_ids => [user_a.id] ) }

    it "should allow edit access to admin user" do
      group = create(:work_group)
      user  = create(:admin_user)
      expect(group.can_be_edited_by?(user)).to be_truthy
    end

    it "should allow edit access to site manager if group belongs to site" do
      site  = create(:site)
      group = create(:work_group, :site_id => site.id)
      user  = create(:site_manager, :site_id => site.id)
      expect(group.can_be_edited_by?(user)).to be_truthy
    end

    it "should not allow edit access to site manager if group does belong to site" do
      site  = create(:site)
      group = create(:work_group)
      user  = create(:site_manager, :site_id => site.id)
      expect(group.can_be_edited_by?(user)).to be_falsey
    end

    it "should allow edit access to user if they are the creator" do
      group = create(:work_group, :users => [current_user], :creator_id => current_user.id)
      expect(group.can_be_edited_by?(current_user)).to be_truthy
    end

    it "should not allow edit access to user if not in group" do
      group = create(:work_group)
      expect(group.can_be_edited_by?(current_user)).to be_falsey
    end

    it "should not allow edit access to user if not only user in group" do
      group = create(:work_group, :users => [current_user])
      expect(group.can_be_edited_by?(current_user)).to be_falsey
    end

    it "should allow edit access to editor of the group" do
      expect(group_a.can_be_edited_by?(user_a)).to be_truthy
    end
  end

  describe "before_add on groups_editors #editor_can_be_added!" do
    let!(:user_a)  { create(:normal_user,    :login => "U_A" ) }
    let!(:user_b)  { create(:normal_user,    :login => "U_B" ) }

    let!(:group_a) { create(:work_group,   :name  => "G_A", :user_ids => [user_a.id] ) }

    it "should only allow member of the group to be an editor" do
      expect{group_a.editor_ids = [user_b.id]}.to raise_error(CbrainError)
    end
  end

  describe "#add_editors" do
    let!(:user_a)  { create(:normal_user,    :login => "U_A" ) }
    let!(:user_b)  { create(:normal_user,    :login => "U_B" ) }
    let!(:user_c)  { create(:normal_user,    :login => "U_C" ) }

    let!(:group_a) { create(:work_group,   :name  => "G_A", :user_ids => [user_a.id, user_b.id] ) }

    it "can add a single editor by id" do
      group_a.add_editors(user_a.id)
      expect(group_a.editor_ids).to include(user_a.id)
    end
    it "can add a single editor by user" do
      group_a.add_editors(user_a)
      expect(group_a.editor_ids).to include(user_a.id)
    end
    it "can ass a list of editors (can be id or User)" do
      group_a.add_editors([user_a.id,user_b])
      expect(group_a.editor_ids).to include(user_a.id, user_b.id)
    end
    it "should be a member of the group to become an editor" do
      group_a.add_editors(user_c.id)
      expect(group_a.editor_ids).not_to include(user_c.id)
    end
    it "no editor should be removed when new is added" do
      group_a.add_editors(user_a)
      group_a.add_editors(user_b)
      expect(group_a.editor_ids).to include(user_a.id, user_b.id)
    end
    it "should not add 2 times the same editor" do
      group_a.add_editors(user_a)
      group_a.add_editors(user_a)
      expect(group_a.editor_ids.keep_if{|i| i == user_a.id }.count).to be(1)
    end
  end

  describe "#remove_editors" do
    let!(:user_a)  { create(:normal_user,    :login => "U_A" ) }
    let!(:user_b)  { create(:normal_user,    :login => "U_B" ) }

    let!(:group_a) { create(:work_group,   :name  => "G_A", :user_ids => [user_a.id, user_b.id] ) }

    before(:each) do
      group_a.add_editors([user_a, user_b])
    end

    it "should remove editor from editors based on it id" do
      group_a.remove_editors(user_a.id)
      expect(group_a.editor_ids).not_to include(user_a.id)
    end
    it "should remove editor from editors based on the user" do
      group_a.remove_editors(user_a)
      expect(group_a.editor_ids).not_to include(user_a.id)
    end
    it "can remove a list of editors (can be id or user)" do
      group_a.remove_editors([user_a.id,user_b])
      expect(group_a.editor_ids).to be_empty
    end
  end

end

