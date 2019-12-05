
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

describe User do

  let(:normal_user) { create(:normal_user, :encrypted_password, password: "1Password!", password_confirmation: "1Password!") }

  describe "#validate" do

    it "should save with valid attributes" do
      normal_user.password = nil # avoid re-encrypting
      expect(normal_user.save).to eq(true)
    end

    it "should not save without a login" do
      normal_user.login = nil
      expect(normal_user.save).to eq(false)
    end

    it "should not save without a full_name" do
      normal_user.full_name = nil
      expect(normal_user.save).to eq(false)
    end

    it "should not save without a password_confirmation" do
      normal_user.password_confirmation = nil
      expect(normal_user.save).to eq(false)
    end

  end



  describe "password verification" do

    it "should not save without a password and password_confirmation that match" do
      normal_user.password = "aksdhflaksjhdfl"
      normal_user.password_confirmation = "ajsdfkl;ajsdflkja9j"
      expect(normal_user.save).to eq(false)
    end

    it "should not accept a password shorter than 4 char" do
      normal_user.password = "abc"
      normal_user.password_confirmation = "abc"
      expect(normal_user.save).to eq(false)
    end

  end



  describe "login verification" do

    it "should not accept a login shorter than 3 char" do
      normal_user.login = "ab"
      expect(normal_user.save).to eq(false)
    end

    it "should check that login is unique" do
      create(:normal_user, :login => "Abcdef")
      bad_login=build(:user, :login => "Abcdef")
      expect(bad_login.save).to be(false)
    end

    it "should check that login is unique even case wise" do
      create(:normal_user, :login => "Abcdef")
      bad_login=build(:user, :login => "abcdef")
      expect(bad_login.save).to be(false)
    end

    it "should prevent me from using the login everyone" do
      normal_user.login = "everyone"
      expect(normal_user.valid?).to  be(false)
    end

    it "should prevent me from using another system group name as login name" do
      create(:system_group, :name => "my_name_is_group")
      normal_user.login = "my_name_is_group"
      expect(normal_user).not_to be_valid
    end

    it "should prevent me from changing my login name" do
      normal_user.password = nil # avoid re-encrypt check
      expect(normal_user.save).to be(true)
      normal_user.login = "not_my_original_login"
      expect(normal_user.save).to be(false)
    end

  end



  describe "email verification" do

    it "should not accept a email address shorter than 3 char" do
      normal_user.email = "a@"
      expect(normal_user.save).to be(false)
    end

  end



  describe "#self.admin" do

    it "should return user with login admin" do
      expect(User.admin).to eq(User.where(:login => "admin").first)
    end

  end



  describe "#self.all_admins" do
    let!(:admin)      {create(:admin_user, :login => "admin_user2")}
    let!(:admin_user) {create(:admin_user, :login => "admin_user")}

    it "should return all users with role admin" do
      expect(User.all_admins(true)).to eq(AdminUser.all)
    end

  end



  describe "#self.authenticate" do

    it "should return nil if user login name does not exist in DB" do
      expect(User.authenticate("thisUsernameIsDummy", "anydummypassword")).to be_nil
    end

    it "should return nil if user is not authenticated" do
      expect(User.authenticate(normal_user.login, normal_user.password + "other")).to be_nil
    end

    it "should return user if user can be found with login and password" do
      allow(normal_user).to receive(:authenticated?).and_return(true)
      allow(User).to receive(:find_by_login).and_return(normal_user)
      expect(User.authenticate(normal_user.login, normal_user.password)).to eq(normal_user)
    end

  end



  describe "#name" do

    it "should return user login" do
      expect(normal_user.login).to eq(normal_user.login)
    end

  end



  describe "#signed_license_agreements" do
    before (:each) do
      allow(RemoteResource).to receive_message_chain(:current_resource, :license_agreements).and_return(["license"])
    end

    it "should return an empty array if meta[:signed_license_agreements] not defined" do
      expect(normal_user.signed_license_agreements).to eq([])
    end

    it "should return a field array if meta[:signed_license_agreements] defined" do
      normal_user.meta[:signed_license_agreements] = ["license"]
      expect(normal_user.signed_license_agreements).to eq(["license"])
    end

  end



  describe "#unsigned_license_agreements" do
    before (:each) do
      allow(RemoteResource).to receive_message_chain(:current_resource, :license_agreements).and_return(["license1","license2"])
    end

    it "should return an empty array if user signed all agreements" do
      normal_user.meta[:signed_license_agreements] = ["license1","license2"]
      expect(normal_user.unsigned_license_agreements).to eq([])
    end

    it "should return an array with the unsigned agreements" do
      normal_user.meta[:signed_license_agreements] = ["license1"]
      expect(normal_user.unsigned_license_agreements).to eq(["license2"])
    end

  end



  describe "#set_random_password" do

    it "should not save user with an unsafe password" do
      normal_user.password = "unsafe"
      expect(normal_user.save).to be(false)
    end

    it "should save user when set_random_password used" do
      normal_user.set_random_password
      expect(normal_user.save).to be(true)
    end

  end



  # Encrypt method in PBKDF2_SHA1
  describe "#self.encrypt_in_pbkdf2_sha1" do

    it "should return a pbkdf2_sha1 string with 64 chars" do
      expect(User.encrypt_in_pbkdf2_sha1(normal_user.password,normal_user.salt).size).to eq(64)
    end

  end



  describe "encrypt_in_pbkdf2_sha1" do

    it "should call class method" do
      expect(User).to receive(:encrypt_in_pbkdf2_sha1).at_least(:once).and_return("pwd")
      normal_user.encrypt_in_pbkdf2_sha1(normal_user.password)
    end

  end



  describe "#authenticated?" do

    it "should return true if crypted_password is equal to encrypt(password)" do
      plain_crypted_password = normal_user.crypted_password
      allow(normal_user).to receive(:encrypt_in_pbkdf2_sha1).and_return(plain_crypted_password)
      expect(normal_user.authenticated?(normal_user.password)).to be(true)
    end

    it "should return false if crypted_password isn't equal to encrypt(password)" do
      allow(normal_user).to receive(:encrypt_in_pbkdf2_sha1).and_return(:other)
      expect(normal_user.authenticated?(normal_user.password)).to be(false)
    end

  end



  describe "has_role?" do

    it "should return true if role is equal self.type" do
      expect(normal_user.has_role?(normal_user.type)).to be(true)
    end

    it "should raise exception if role isn't equal self.type" do
      expect { normal_user.has_role?(normal_user.type + "other") }.to raise_error(NameError, /uninitialized constant/)
    end

  end



  describe "#availability" do
    let!(:admin)        { create(:admin_user) }
    let!(:group)        { create(:group) }
    let!(:site_manager) { create(:site_manager, :group_ids => [group.id] ) }

    describe "#tool" do
      let!(:tool1)        { create(:tool, :group_id => group.id) }
      let!(:tool2)        { create(:tool, :category => "conversion tool") }

      describe "#available_tools" do

        it "should return all tools if called with an admin" do
          expect(Tool).to receive(:where).with(nil)
          admin.available_tools
        end

        it "should return all tools available for site_manager" do
          expect(site_manager.available_tools).to match_array([tool1])
        end

        it "should return a tool if one of the user of the site have acces to the tool" do
          normal_user.tool_ids = [tool2.id]
          normal_user.password = nil # avoid re-encrypt check
          expect(normal_user.save).to be(true)
          allow(site_manager).to receive_message_chain(:site, :user_ids).and_return([site_manager.id, normal_user.id])
          expect(site_manager.available_tools).to match_array([tool1,tool2])
        end

        it "should return tools available for a standard user" do
          normal_user.tool_ids = [tool2.id]
          normal_user.password = nil # avoid re-encrypt check
          expect(normal_user.save).to be(true)
          expect(normal_user.available_tools).to eq([tool2])
        end

      end

    end



    describe "#available_groups" do
      let!(:invisible_group) {create(:invisible_group)}

      it "should return all groups if called with an admin" do
        expect(admin.available_groups).to match(Group.all)
      end

      it "should not return invisible group for site_manager" do
        invisible_group.user_ids = [site_manager.id]
        invisible_group.save
        expect(site_manager.available_groups).not_to include(invisible_group)
      end

      it "should not include everyone group for site_manager" do
        expect(site_manager.available_groups).not_to include(Group.where(:name => "everyone").first)
      end

      it "should not return invisible group for standard user" do
        invisible_group.user_ids = [normal_user.id]
        invisible_group.save
        expect(normal_user.available_groups).not_to include(invisible_group)
      end

      it "should not include everyone group for standard user" do
        expect(normal_user.available_groups).not_to include(Group.where(:name => "everyone"))
      end


    end



    describe "#available_tags" do
      let!(:my_tag)     {create(:tag,  :user_id => normal_user.id, :group_id => group.id )}
      let!(:other_user) {create(:normal_user, :group_ids => [group.id])}

      it "should return tag if it's mine" do
        expect(normal_user.available_tags).to include(my_tag)
      end

      it "should return tag if tag is in a group I can access" do
        expect(other_user.available_tags).to include(my_tag)
      end

    end



    describe "#available_tasks" do
      let!(:my_task)      {create(:cbrain_task, :user_id => normal_user.id)}
      let!(:user_of_site) {create(:normal_user, :site => site_manager.site)}

      it "should return all tasks if called with an admin" do
        expect(CbrainTask).to receive(:where).with(nil)
        admin.available_tasks
      end

      it "should return task of site user" do
        site            = site_manager.site
        site.user_ids   = [user_of_site.id]
        site.save
        my_task.user_id = user_of_site.id
        my_task.save
        expect(site_manager.available_tasks).to include(my_task)
      end

      it "should return my task if I'm a standard user" do
        expect(normal_user.available_tasks).to include(my_task)
      end

    end



    describe "#available_users" do
      let!(:user_of_site) { create(:normal_user, :site_id => site_manager.site.id) }

      it "should return all tasks if called with an admin" do
        expect(admin.available_users).to match(User.all)
      end

      it "should acces to all site users if site_manager" do
        site = site_manager.site
        site.reload
        expect(site_manager.available_users).to match_array([user_of_site,site_manager])
      end

      it "should only acces to him" do
        expect(normal_user.available_users).to match_array([normal_user])
      end

    end



    describe "#can_be_accessed_by?" do
      let!(:user_of_site) {create(:normal_user, :site => site_manager.site)}

      it "should always return true if admin" do
        expect(normal_user.can_be_accessed_by?(admin)).to be_truthy
      end

      it "should user can be accessible by a site manager if in same site" do
        site            = site_manager.site
        site.user_ids   = [user_of_site.id,normal_user.id]
        site.save
        expect(user_of_site.can_be_accessed_by?(site_manager)).to be_truthy
      end

      it "should user can't be accessible by a site manager if not in same site" do
        site            = site_manager.site
        site.user_ids   = [user_of_site.id]
        site.save
        expect(normal_user.can_be_accessed_by?(site_manager)).to be_falsey
      end

      it "should only have access to him (for standard user)" do
        expect(normal_user.can_be_accessed_by?(normal_user)).to be_truthy
      end

      it "should not access to an other user (for standard user)" do
        expect(normal_user.can_be_accessed_by?(user_of_site)).to be_falsey
      end

    end

  end



  describe "#system_group" do

    it "should return the system group of user" do
      expect(normal_user.system_group).to eq(UserGroup.where( :name => normal_user.login ).first)
    end

  end



  describe "#is_member_of_group" do
    let!(:group) {create(:group)}
    let!(:user_of_group_2) {create(:normal_user, :group_ids => [group.id])}

    it "should returns true if the user belongs to the +group_id+" do
      expect(user_of_group_2.is_member_of_group(group)).to be_truthy
    end

    it "should returns false if the user not belongs to the +group_id+" do
      expect(normal_user.is_member_of_group(group.id)).to be_falsey
    end

  end



  describe "#destroy_user_sessions" do

    it "should return true if user have no id" do
      normal_user.id = nil
      expect(normal_user.destroy_user_sessions).to be_truthy
    end

    it "should call destroy user session" do
      user_id = LargeSessionInfo.all.map(&:user_id).first
      nb_session_after_delete = (LargeSessionInfo.all.count - LargeSessionInfo.where(:user_id => user_id).count)
      normal_user.id = user_id
      normal_user.destroy_user_sessions
      expect(LargeSessionInfo.all.count).to eq(nb_session_after_delete)
    end

  end



  describe "#immutable_login" do

    it "should not change login name of user" do
      normal_user.login = "new_pseudo"
      expect(normal_user.save).to be(false)
    end

  end



  describe "#admin_check" do

    it "should raise error if when try to destroy admin" do
      admin = User.admin
      expect{ admin.destroy }.to raise_error(ActiveRecord::DeleteRestrictionError, /Cannot delete record/)
    end

  end



  describe "#system_group_site_update" do
    let!(:site1) { create(:site) }

    it "should add user to new site" do
      normal_user.site = site1
      normal_user.password = nil # avoid re-encrypting
      expect(normal_user.save).to be(true)
      expect(site1.own_group.users).to include(normal_user)
    end

    it "should remove user to old site" do
      start_site = normal_user.site = create(:site)
      normal_user.site = site1
      normal_user.password = nil # avoid re-encrypting
      expect(normal_user.save).to be(true)
      expect(start_site.own_group.users).not_to include(normal_user)
    end
  end



  describe "#site_manager_check" do

    it "should not save a site manager without a site_id" do
      normal_user.type    = "SiteManager"
      normal_user.site_id = nil
      no_site_manager =  normal_user.class_update
      expect(no_site_manager.save).to be_falsey
    end

  end



  describe "#destroy_system_group" do

    it "should destroy system group of user if user destroyed" do
      user_login = normal_user.login
      normal_user.destroy
      expect(SystemGroup.where(:name => user_login)).to be_empty
    end
  end



  describe "#create_user" do
    let(:site) { create(:site) }

    it "User should be part of his own group, everyone group, and his site" do
      new_user = create(:normal_user, :site => site)
      everyone_group_id = Group.everyone.id
      site_group_id     = site.own_group.id
      user_group_id     = new_user.own_group.id
      expect(new_user.group_ids).to include(user_group_id, site_group_id,everyone_group_id)
    end

    it "should create a new UserGroup with my login on create" do
       login = "login"
       allow_any_instance_of(NormalUser).to receive(:group_ids=)
       expect(UserGroup).to receive(:new).with(hash_including(:name => login)).and_return(mock_model(UserGroup).as_null_object)
       create(:normal_user, :login => login)
     end

  end

  describe "#system_group_site_update" do
    it "should add me to the site group" do
      site             = create(:site, :name => "I_should_be_part_of_this_site_group")
      normal_user.site = site
      normal_user.password = nil # don't want to encrypt it here
      expect(normal_user.save).to be(true)
      site.reload
      expect(site.user_ids).to include(normal_user.id)
    end
  end

  context "access profiles" do

    # User 'A', Group 'A' and AP 'A' all link together
    let(:user_a)  { create(:normal_user,    :login => "U_A") }
    let(:group_a) { create(:work_group,     :name  => "G_A",  :user_ids => [ user_a.id ] ) }
    let(:ap_a)    { create(:access_profile, :name  => "AP_A", :user_ids => [ user_a.id ], :group_ids => [ group_a.id ] ) }

    # User 'A', Group 'B' and AP 'B' all link together
    let(:group_b) { create(:work_group,     :name  => "G_B",  :user_ids => [ user_a.id ] ) }
    let(:ap_b)    { create(:access_profile, :name  => "AP_B", :user_ids => [ user_a.id ], :group_ids => [ group_b.id ] ) }

    # User 'A' is in Group 'O', not in any AP
    let(:group_o) { create(:work_group,     :name  => "G_Oth", :user_ids  => [ user_a.id ] ) }

    # User 'A' is in AP 'C', which contains Groups 'A' and 'B' already
    let(:ap_c)    { create(:access_profile, :name  => "AP_C", :user_ids => [ user_a.id ], :group_ids => [ group_a.id, group_b.id] ) }

    describe "#union_group_ids_from_access_profiles" do
      it "should iterate over all access_profiles" do
        expect(user_a).to receive(:access_profiles).and_return([ ap_a, ap_b, ap_c ])
        expect(ap_a).to   receive(:group_ids).and_return([ group_a.id ])
        expect(ap_b).to   receive(:group_ids).and_return([ group_b.id ])
        expect(ap_c).to   receive(:group_ids).and_return([ group_a.id, group_b.id ])
        expect(user_a.union_group_ids_from_access_profiles).to match_array( [ group_a.id, group_b.id ] )
      end
    end

    describe "#apply_access_profiles" do
      it "should build a list of all groups IDs of all profiles" do
        allow(user_a).to receive(:union_group_ids_from_access_profiles).and_return( [ group_a.id, group_b.id ] )
        user_a.apply_access_profiles(remove_group_ids: [])
        expect(user_a.group_ids - [ Group.everyone.id, user_a.own_group.id ]).to match_array( [ group_a.id, group_b.id ] )
      end
      it "should remove groups IDs unless they are in a profile" do
        allow(user_a).to receive(:union_group_ids_from_access_profiles).and_return( [ group_a.id, group_b.id ] )
        user_a.group_ids          = [ group_a.id, group_o.id ]
        user_a.access_profile_ids = [ ap_a.id, ap_b.id ]
        user_a.apply_access_profiles(remove_group_ids: [ group_a.id, group_o.id ])
        expect(user_a.group_ids).to match_array( [ group_a.id, group_b.id ] )
      end
    end

  end

end

