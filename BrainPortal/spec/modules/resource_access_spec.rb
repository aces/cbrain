
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

describe ResourceAccess do
  let(:normal_user)    { create(:normal_user) }
  let(:site_manager)   { create(:site_manager) }
  let(:admin)          { create(:admin_user) }
  let(:free_resource)  { create(:cbrain_task) }
  let(:group_resource) { create(:cbrain_task, :group => user.groups.last) }
  let(:site_resource)  { create(:cbrain_task, :user => create(:normal_user, :site => user.site)) }
  let(:owned_resource) { create(:cbrain_task, :user => user) }


  describe "#can_be_accessed_by?" do
    describe "for admins" do
      let(:user) { admin }

      it "should give access to owned resource" do
        expect(owned_resource.can_be_accessed_by?(admin)).to be_truthy
      end
      it "should give access to site-associated resource" do
        expect(site_resource.can_be_accessed_by?(admin)).to be_truthy
      end
      it "should give access to group-associated resource" do
        expect(group_resource.can_be_accessed_by?(admin)).to be_truthy
      end
      it "should give access to non-associated resource" do
        expect(free_resource.can_be_accessed_by?(admin)).to be_truthy
      end
    end
    describe "for site managers" do
      let(:user) { site_manager }

      it "should give access to owned resource" do
        expect(owned_resource.can_be_accessed_by?(site_manager)).to be_truthy
      end
      it "should give access to site-associated resource" do
        expect(site_resource.can_be_accessed_by?(site_manager)).to be_truthy
      end
      it "should give access to group-associated resource" do
        expect(group_resource.can_be_accessed_by?(site_manager)).to be_truthy
      end
      it "should not give access to non-associated resource" do
        expect(free_resource.can_be_accessed_by?(site_manager)).to be_falsey
      end
    end
    describe "for regular users" do
      let(:user) { normal_user }

      it "should give access to owned resource" do
        expect(owned_resource.can_be_accessed_by?(user)).to be_truthy
      end
      it "should not give access to site-associated resource" do
        expect(site_resource.can_be_accessed_by?(user)).to be_falsey
      end
      it "should give access to group-associated resource" do
        expect(group_resource.can_be_accessed_by?(user)).to be_truthy
      end
      it "should not give access to non-associated resource" do
        expect(free_resource.can_be_accessed_by?(user)).to be_falsey
      end
    end
  end

  describe "#has_owner_access?" do
    describe "for admins" do
      let(:user) { admin }
      it "should give access to owned resource" do
        expect(owned_resource.has_owner_access?(admin)).to be_truthy
      end
      it "should give access to site-associated resource" do
        expect(site_resource.has_owner_access?(admin)).to be_truthy
      end
      it "should give access to group-associated resource" do
        expect(group_resource.has_owner_access?(admin)).to be_truthy
      end
      it "should give access to non-associated resource" do
        expect(free_resource.has_owner_access?(admin)).to be_truthy
      end
    end
    describe "for site managers" do
      let(:user) { site_manager }

      it "should give access to owned resource" do
        expect(owned_resource.has_owner_access?(site_manager)).to be_truthy
      end
      it "should give access to site-associated and group-associated resource" do
        site_resource.group.site_id = site_resource.user.site_id
        expect(site_resource.has_owner_access?(site_manager)).to be_truthy
      end
      it "should not give access to site-associated resource" do
        expect(site_resource.has_owner_access?(site_manager)).to be_falsey
      end
      it "should not give access to group-associated resource" do
        expect(group_resource.has_owner_access?(site_manager)).to be_falsey
      end
      it "should not give access to non-associated resource" do
        expect(free_resource.has_owner_access?(site_manager)).to be_falsey
      end
    end
    describe "for regular users" do
      let(:user) { normal_user }

      it "should give access to owned resource" do
        expect(owned_resource.has_owner_access?(user)).to be_truthy
      end
      it "should not give access to site-associated resource" do
        expect(site_resource.has_owner_access?(user)).to be_falsey
      end
      it "should not give access to group-associated resource" do
        expect(group_resource.has_owner_access?(user)).to be_falsey
      end
      it "should not give access to non-associated resource" do
        expect(free_resource.has_owner_access?(user)).to be_falsey
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
        # BTW: fails if the rake task 'db:sanity:check' was not run
        expect(CbrainTask.find_all_accessible_by_user(admin).map(&:id)).to match_array([free_resource.id, group_resource.id, site_resource.id, owned_resource.id])
      end
    end

    describe "for site managers" do
      let(:user) { site_manager }
      it "should return owned, group and site-associated resources for site managers" do
        free_resource
        group_resource
        site_resource
        owned_resource
        expect(CbrainTask.find_all_accessible_by_user(site_manager).map(&:id)).to match_array([group_resource.id, site_resource.id, owned_resource.id])
      end
    end

    describe "for regular users" do
      let(:user) { normal_user }
      it "should return owned and group-associated resources for regular users" do
        free_resource
        group_resource
        site_resource
        owned_resource
        expect(CbrainTask.find_all_accessible_by_user(user).map(&:id)).to match_array([group_resource.id, owned_resource.id])
      end
    end

  end

  describe "#find_accessible_by_user" do
    describe "for admins" do
      let(:user) { admin }

      it "should find owned resources" do
        expect(CbrainTask.find_accessible_by_user(owned_resource.id, admin).id).to eq(owned_resource.id)
      end
      it "should find site-associated resources" do
        expect(CbrainTask.find_accessible_by_user(site_resource.id, admin).id).to eq(site_resource.id)
      end
      it "should find group-associated resources" do
        expect(CbrainTask.find_accessible_by_user(group_resource.id, admin).id).to eq(group_resource.id)
      end
      it "should find non-associated resources" do
        expect(CbrainTask.find_accessible_by_user(free_resource.id, admin).id).to eq(free_resource.id)
      end
    end
    describe "for site managers" do
      let(:user) { site_manager }

      it "should find owned resources" do
        expect(CbrainTask.find_accessible_by_user(owned_resource.id, site_manager).id).to eq(owned_resource.id)
      end
      it "should find site-associated resources" do
        expect(CbrainTask.find_accessible_by_user(site_resource.id, site_manager).id).to eq(site_resource.id)
      end
      it "should find group-associated resources" do
        expect(CbrainTask.find_accessible_by_user(group_resource.id, site_manager).id).to eq(group_resource.id)
      end
      it "should raise ActiveRecord::RecordNotFound when used to find non-associated resources" do
        expect{CbrainTask.find_accessible_by_user(free_resource.id, site_manager)}.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
    describe "for users" do
      let(:user) { normal_user }

      it "should find owned resources" do
        expect(CbrainTask.find_accessible_by_user(owned_resource.id, user).id).to eq(owned_resource.id)
      end
      it "should rause ActiveRecord::RecordNotFound when used to find site-associated resources" do
        expect{CbrainTask.find_accessible_by_user(site_resource.id, user)}.to raise_error(ActiveRecord::RecordNotFound)
      end
      it "should find group-associated resources" do
        expect(CbrainTask.find_accessible_by_user(group_resource.id, user).id).to eq(group_resource.id)
      end
      it "should rause ActiveRecord::RecordNotFound when used to find non-associated resources" do
        expect{CbrainTask.find_accessible_by_user(free_resource.id, user)}.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end

