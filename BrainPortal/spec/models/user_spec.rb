
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

describe User do

  fixtures :groups
  
  before(:each) do 
    @user = Factory.create(:normal_user)
  end

  describe "#validate" do 
    
    it "should save with valid attributes" do
      @user.save
    end
  
    it "should not save without a login" do
      @user.login = nil
      @user.save.should == false
    end
  
    it "should not save without a full_name" do
      @user.full_name = nil
      @user.save.should == false
    end
  
    it "should not save without a type" do 
      @user.type = nil
      @user.save.should == false
    end
  
    it "should not save with blank password" do
      @user.password = ""
      @user.save.should == false
    end
  
    it "should not save without a password_confirmation" do
      @user.password_confirmation = nil 
      @user.save.should == false
    end
    
  end
  

  
  describe "password verification" do
  
    it "should not save without a password and password_confirmation that match" do
      @user.password = "aksdhflaksjhdfl"
      @user.password_confirmation = "ajsdfkl;ajsdflkja9j"
      @user.save.should == false
    end
  
    it "should not accept a password shorter than 4 char" do
      @user.password = "abc"
      @user.password_confirmation = "abc"
      @user.save.should == false
    end
    
  end

  
  
  describe "login verification" do
    
    it "should not accept a login shorter than 3 char" do
      @user.login = "ab"
      @user.save.should == false
    end

    it "should check that login is unique" do
      Factory.create(:normal_user, :login => "Abcdef")
      bad_login=Factory.build(:user, :login => "Abcdef")
      bad_login.save.should be(false)
    end
  
    it "should check that login is unique even case wise" do
      Factory.create(:normal_user, :login => "Abcdef")
      bad_login=Factory.build(:user, :login => "abcdef")
      bad_login.save.should be(false)
    end

    it "should prevent me from using the login everyone" do
      @user.login = "everyone"
      @user.valid?.should  be(false)
    end

    it "should prevent me from using another system group name as login name" do
      Factory.create(:system_group, :name => "my_name_is_group")
      @user.login = "my_name_is_group"
      @user.should_not be_valid
    end
  
    it "should prevent me from changing my login name" do
      @user.save
      @user.login = "not_my_orginal_login"
      @user.save.should  be(false)
    end
    
  end


  
  describe "email verification" do
    
    it "should not accept a email address shorter than 3 char" do
      @user.email = "a@"
      @user.save.should be(false)
    end
    
  end

  
  
  describe "#self.admin" do
    let!(:admin) {Factory.create(:admin_user, :login => "admin")}
    
    it "should return user with login admin" do
      User.admin.should be == User.where(:login => "admin").first
    end
    
  end


  
  describe "#self.all_admins" do
    let!(:admin) {Factory.create(:admin_user, :login => "admin")}
    let!(:admin_user) {Factory.create(:admin_user, :login => "admin_user")}
    
    it "should return all users with role admin" do
      User.all_admins.should be == AdminUser.all
    end
    
  end


  
  describe "#self.authenticate" do
    
    it "should return nil if user is not authenticates" do 
      User.authenticate(@user.login, @user.password + "other").should be_nil 
    end

    it "should return user if user can be found with login and password" do
      User.authenticate(@user.login, @user.password).should be == @user 
    end
  
  end


  
  describe "#name" do
    
    it "should return user login" do 
      @user.login.should be == @user.login    
    end
    
  end


  
  describe "#signed_license_agreements" do

    it "should return an empty array if meta[:signed_license_agreements] not defined" do
      @user.signed_license_agreements.should be == []
    end

    it "should return a field array if meta[:signed_license_agreements] defined" do
      @user.meta[:signed_license_agreements] = ["license"]
      @user.signed_license_agreements.should be == ["license"]
    end
    
  end


  
  describe "#unsigned_license_agreements" do
    before (:each) do
      RemoteResource.stub_chain(:current_resource, :license_agreements).and_return(["license1","license2"])
    end
      
    it "should return an empty array if user signed all agreements" do
      @user.meta[:signed_license_agreements] = ["license1","license2"]
      @user.unsigned_license_agreements.should be == []
    end

    it "should return an array with the unsigned agreements" do
      @user.meta[:signed_license_agreements] = ["license1"]
      @user.unsigned_license_agreements.should be == ["license2"]
    end
    
  end


  
  describe "#set_random_password" do

    it "should not save user with an unsafe password" do
      @user.password = "unsafe"
      @user.save.should be(false) 
    end

    it "should save user when set_random_password used" do
      @user.set_random_password
      @user.save.should be(true)
    end
    
  end


  
  describe "#self.encrypt" do

    it "should call Digest::SHA1" do
      Digest::SHA1.should_receive(:hexdigest)
      User.encrypt(@user.password, @user.salt) 
    end
    
  end


  
  describe "#encrypt" do

    it "should encrypts password with the user salt" do
      User.should_receive(:encrypt).with(@user.password,@user.salt)
      @user.encrypt(@user.password)
    end
    
  end


  
  describe "#autheticated?" do

    it "should return true if crypted_password is equal to encrypt(password)" do
      @user.authenticated?(@user.password).should be(true) 
    end

    it "should return false if crypted_password isn't equal to encrypt(password)" do
      @user.authenticated?(@user.password + "other").should be(false) 
    end
    
  end


  
  describe "#remenber_token?" do

    it "should return true if remember_token_expires_at is before now" do
      @user.remember_token_expires_at = Time.now + 2.weeks
      @user.remember_token?.should be(true)   
    end

    it "should return false if remember_token_expires_at is after now" do
      @user.remember_token_expires_at = Time.now - 2.weeks
      @user.remember_token?.should be(false)   
    end
  
  end


  
  describe "#remember_me" do

    it "should call remember_me_for" do
      @user.should_receive(:remember_me_for)
      @user.remember_me
    end
    
  end


  
  describe "#remember_me_for" do

    it "should call remenber_me_until" do
      @user.should_receive(:remember_me_until)
      @user.remember_me_for(1.weeks)
    end
        
  end


  
  describe "#remember_me_until" do
  
    it "should set new time for remember_token_expires_at" do
      new_time = Time.now + 2.weeks
      @user.remember_me_until(new_time)
      @user.remember_token_expires_at.should be == new_time
    end

    it "should encrypt email and remember_token_expires_at" do
      @user.should_receive(:encrypt).any_number_of_times
      @user.remember_me_until(new_time = Time.now + 2.weeks)
    end
    
  end


  
  describe "#forget_me" do
    
    it "should set remember_token_expires_at to nil" do
      @user.remember_me_until(Time.now + 2.weeks)
      @user.forget_me
      @user.remember_token_expires_at.should be_nil 
    end
      
    it "should set remember_token_expires_at to nil" do
      @user.remember_me_until(Time.now + 2.weeks)
      @user.forget_me
      @user.remember_token.should be_nil 
    end
                        
    
  end

  

  describe "has_role?" do
    
    it "should return true if role is equal self.type" do
      @user.has_role?(@user.type).should be(true)
    end

    it "should raise exception if role isn't equal self.type" do
      lambda { @user.has_role?(@user.type + "other") }.should raise_error
    end

  end


  
  describe "#availability" do
    let!(:admin)        {Factory.create(:admin_user)}
    let!(:group)        {Factory.create(:group, :id => "2" ) }
    let!(:site_manager) {Factory.create(:site_manager, :group_ids => ["2"])}
    
    describe "#tool" do
      let!(:tool1)        {Factory.create(:tool, :group_id => "2")}
      let!(:tool2)        {Factory.create(:tool, :category => "conversion tool")}

      describe "#available_tools" do

        it "should return all tools if called with an admin" do
          admin.available_tools.should be =~ Tool.all
        end

        it "should return all tools available for site_manager" do
          site_manager.available_tools.should be =~ [tool1] 
        end

        it "should return a tool if one of the user of the site have acces to the tool" do
          @user.tool_ids = [tool2.id]
          @user.save
          site_manager.available_tools.should be =~ [tool1,tool2]
        end

        it "should return tools available for a standard user" do
          tool_id = tool2.id
          @user.tool_ids = [tool_id]
          @user.save
          @user.available_tools.should be == [tool2] 
        end 
        
      end


  
      describe "#available_scientific_tools" do
      
        it "should only return scientific tool" do
          admin.available_scientific_tools.should be == [tool1] 
        end
      
      end


      
      describe "#available_conversion_tools" do
        
        it "should only return conversion tool" do
          admin.available_conversion_tools.should be == [tool2] 
        end
        
      end
      
    end
  

  
    describe "#available_groups" do
      let!(:invisible_group) {Factory.create(:invisible_group)}
      
      it "should return all groups if called with an admin" do
        admin.available_groups.should be =~ Group.all
      end

      it "should not return invisible group for site_manager" do
        invisible_group.user_ids = [site_manager.id]
        invisible_group.save
        site_manager.available_groups.should_not include(invisible_group) 
      end

      it "should not include everyone group for site_manager" do
        site_manager.available_groups.should_not include(Group.where(:name => "everyone").first) 
      end

      it "should not return invisible group for standard user" do
        invisible_group.user_ids = [@user.id]
        invisible_group.save
        @user.available_groups.should_not include(invisible_group) 
      end

      it "should not include everyone group for standard user" do
        @user.available_groups.should_not include(Group.where(:name => "everyone")) 
      end

      
    end


  
    describe "#available_tags" do
      let!(:my_tag)     {Factory.create(:tag,  :user_id => @user.id, :group_id => "2" )}
      let!(:other_user) {Factory.create(:normal_user, :group_ids => ["2"])}
      
      it "should return tag if it's mine" do
        @user.available_tags.should include(my_tag) 
      end

      it "should return tag if tag is in a group I can access" do
        other_user.available_tags.should include(my_tag) 
      end
      
    end

  

    describe "#available_tasks" do
      let!(:my_task)      {Factory.create(:cbrain_task, :user_id => @user.id)}
      let!(:user_of_site) {Factory.create(:normal_user, :site => site_manager.site)}
      
      it "should return all taskss if called with an admin" do
        admin.available_tasks.should be =~ CbrainTask.all 
      end

      it "should return task of site user" do
        site            = site_manager.site
        site.user_ids   = [user_of_site.id]
        site.save
        my_task.user_id = user_of_site.id 
        my_task.save
        site_manager.available_tasks.should include(my_task)
      end

      it "should return my task if I'm a standard user" do
        @user.available_tasks.should include(my_task) 
      end
      
    end

  
  
    describe "#available_users" do
      let!(:user_of_site) {Factory.create(:normal_user, :site => site_manager.site)}
      
      it "should return all tasks if called with an admin" do
        admin.available_users.should be =~ User.all
      end

      it "should acces to all site users site_manager" do
        site            = site_manager.site
        site.user_ids   = [user_of_site.id,@user.id]
        site.save
        site_manager.available_users.should be  =~ [user_of_site,@user,site_manager]
      end

      it "should only acces to him" do
        @user.available_users.should be =~ [@user]
      end
      
    end


  
    describe "#can_be_accessed_by?" do
      let!(:user_of_site) {Factory.create(:normal_user, :site => site_manager.site)}
      
      it "should always return true if admin" do
        @user.can_be_accessed_by?(admin).should be(true)
      end

      it "shoulda user can be accessible by a site manager if in same site" do
        site            = site_manager.site
        site.user_ids   = [user_of_site.id,@user.id]
        site.save
        user_of_site.can_be_accessed_by?(site_manager).should be_true  
      end

      it "should user can't be accessible by a site manager if not in same site" do
        site            = site_manager.site
        site.user_ids   = [user_of_site.id]
        site.save
        @user.can_be_accessed_by?(site_manager).should be_false  
      end

      it "should only have access to him (for standard user)" do
        @user.can_be_accessed_by?(@user).should be_true 
      end

      it "should not access to an other user (for standard user)" do
        @user.can_be_accessed_by?(user_of_site).should be_false
      end
      
    end
    
  end


  
  describe "#system_group" do
    
    it "should return the system group of user" do
      @user.system_group.should be == UserGroup.where( :name => @user.login ).first 
    end
    
  end


  
  describe "#is_member_of_group" do
    let!(:group) {Factory.create(:group, :id => "2")}
    let!(:user_of_group_2) {Factory.create(:normal_user, :group_ids => ["2"])}
    
    it "should returns true if the user belongs to the +group_id+" do
      user_of_group_2.is_member_of_group(group).should be_true
    end

    it "should returns false if the user not belongs to the +group_id+" do
      @user.is_member_of_group("2").should be_false
    end
    
  end


  
  describe "#destroy_user_sessions" do
    let!(:session)    {{:user_id => @user.id}}
    let!(:sess_model) {double("sess_model").as_null_object}
    let!(:cb_session) {mock_model(ActiveRecord::SessionStore::Session).as_null_object}
    
    it "should return true if user have no id" do
      @user.id = nil
      @user.destroy_user_sessions.should be_true
    end

    it "should call destroy on user session" do
      CbrainSession.stub(:all).and_return(double'all_session', :select => [cb_session])
      cb_session.should_receive(:destroy)
      @user.destroy_user_sessions
    end
    
  end


  
  describe "#immutable_login" do
    
    it "should not change login name of user" do
      @user.login = "new_pseudo"
      @user.save.should be(false)
    end
    
  end


  
  describe "#admin_check" do
    let!(:admin) {Factory.create(:admin_user, :login => "admin")}
    
    it "should raise error if when try to destroy admin" do
      lambda{ admin.destroy }.should raise_error
    end
    
  end


  
  describe "#system_group_site_update" do
    let!(:site1) {Factory.create(:site, :id => "1") }
    
    it "should add user to new site" do
      @user.site = site1
      @user.save
      site1.own_group.users.should include(@user) 
    end

    it "should remove user to old site" do
      start_site = @user.site
      @user.site = site1
      @user.save
      start_site.own_group.users.should_not include(@user)
    end
  end


  
  describe "#site_manager_check" do
    
    it "should not save a site manager without a site_id" do
      @user.type    = "SiteManager"
      @user.site_id = nil
      @user.save.should be(false)
    end
    
  end


  
  describe "#destroy_system_group" do
    
    it "should destroy system group of user if user destroyed" do
      user_login = @user.login
      @user.destroy
      SystemGroup.where(:name => user_login).should be_empty  
    end
  end


  
  describe "#add_system_groups" do
    
    it "should found a SystemGroup with name equal user.login" do
      SystemGroup.where(:name => @user.login).count.should be == 1 
    end

    it "User should be part of is own group everyone group and these sites" do
      user_sites_group = SiteGroup.joins(:users).where("users.id" => [@user.id]).map &:id
      user_group       = SystemGroup.where(:name => @user.login).map &:id
      everyone_group   = Group.where(:name => "everyone").map &:id
      all_user_group   = user_sites_group + user_group + everyone_group
      @user.group_ids.should be =~ all_user_group 
    end
    
  end

  

  it "should check that a user is a site_manager on save" do
    @user.type = "SiteManager"
    @user.save
    @user.site.managers.include?(@user).should be(true)
  end


  
  it "should create a new UserGroup with my login on create" do
    user_group=UserGroup.find_by_name(@user.login)
    user_group.instance_of?(UserGroup).should be(true)
  end

  
  
  it "should add me to the everyone group" do
    @user.groups.include?(Group.everyone).should be(true)
  end

  
  
  it "should add me to the site group" do
    @user.site = Factory.create(:site, :name => "I_should_be_part_of_this_site_group")
    @user.save!
    @user.reload
    @user.groups.include?(SystemGroup.find_by_name("I_should_be_part_of_this_site_group")).should be(true)
  end
  
end

