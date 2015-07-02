
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

describe Userfile do
  let(:userfile)     { create(:text_file) }
  let(:user)         { create(:normal_user) }
  let(:site_manager) { create(:site_manager) }
  let(:admin)        { create(:admin_user) }

  it "should be valid with valid attributes" do
    expect(userfile.valid?).to be true
  end

  it "should require a name" do
    userfile.name = nil
    expect(userfile.valid?).to be false
  end

  it "should require a user" do
    userfile.user = nil
    expect(userfile.valid?).to be false
  end

  it "should require a group" do
    userfile.group = nil
    expect(userfile.valid?).to be false
  end

  it "should require that the user has no other files with the same name in the same data_provider" do
    userfile.name = "abc"
    userfile.save
    bad_file= build( :userfile, :name => "abc",
                                       :user => userfile.user,
                                       :data_provider => userfile.data_provider )
    expect(bad_file.valid?).to be false
  end

  describe Userfile::Viewer do
    let(:viewer) {Userfile::Viewer.new(userfile.class, {:userfile_class => userfile.class.name, :name => "name", :partial => "partial"})}

    describe "#initialize" do

      it "should transform string into hash" do
        name = "name"
        viewer_test    = Userfile::Viewer.new(userfile.class,name)
        name_result    = name.to_s.classify.gsub(/(.+)([A-Z])/, '\1 \2')
        partial_result = name.to_s.underscore
        expect(viewer_test.name).to    eq(name_result)
        expect(viewer_test.partial).to eq(partial_result)
      end
    end

    describe "#initialize_from_hash" do

      it "should return cbrain error if atts have no key name and no key partial" do
        expect{viewer.initialize_from_hash({})}.to raise_error(CbrainError)
      end

      it "should return cbrain error if we have an unknow viewer" do
        expect{viewer.initialize_from_hash({:name => "name", :partial => "partial", :other => "other"})}.to raise_error(CbrainError)
      end

      it "should raise cbrain error if condition does not respond_to :to_proc" do
        allow(String).to receive(:respond_to?).and_return(false)
        expect{viewer.initialize_from_hash({:name => "name", :partial => "partial", :if => "condition"})}.to raise_error(CbrainError)
      end
    end

    describe "#valid_for?" do
      let(:viewer_with_condition) {Userfile::Viewer.new(userfile.class, {:name => "name", :partial => "partial", :if => lambda {|u| u.name == "userfile_name"}})}

      it "should return true if @conditions is empty" do
        expect(viewer.valid_for?(userfile)).to be_truthy
      end

      it "should call call on condition" do
        userfile.name = "userfile_name"
        expect(viewer_with_condition.valid_for?(userfile)).to be_truthy
      end
    end

    describe "#==" do
      let(:other1)  {Userfile::Viewer.new(userfile.class, {:name => "name", :partial => "partial"})}
      let(:other2)  {Userfile::Viewer.new(userfile.class, {:name => "other", :partial => "partial"})}

      it "should return false if other is not a Viewer" do
        expect(viewer.==("other1")).to be_falsey
      end

      it "should return true if Viewer have same name" do
        expect(viewer.==(other1)).to be_truthy
      end

      it "should return false if Viewer have different name" do
        expect(viewer.==(other2)).to be_falsey
      end
    end

  end

  describe "#viewers" do

    it "should call class.class_viewers" do
      userfile_class = double("userfile")
      expect(userfile).to receive(:class).and_return(userfile_class)
      expect(userfile_class).to receive(:class_viewers).and_return([])
      userfile.viewers
    end
  end

  describe "#find_viewer(name)" do

    it "should call viewers.find" do
      userfile_viewers = double(["viewer1","viewer2"])
      expect(userfile).to receive(:viewers).and_return(userfile_viewers)
      expect(userfile_viewers).to receive(:find).and_return([])
      userfile.find_viewer("viewer1")
    end
  end

  describe "#site" do

    it "should return the users site when site is called" do
      userfile.save
      expect(userfile.site).to eq(userfile.user.site)
    end
  end

  describe "#self.pseudo_sort_columns" do

    it "should return a pseudo array" do
      userfile
      expect(Userfile.pseudo_sort_columns).to eq(["tree_sort"])
    end
  end

  describe "#file_extension" do

    it "should call class.file_extension" do
      userfile_class = double("userfile")
      expect(userfile).to receive(:class).and_return(userfile_class)
      expect(userfile_class).to receive(:file_extension)
      userfile.file_extension
    end
  end

  describe "#self.file_extension(name)" do

    it "should call scan and last on name" do
      userfile_name = double("name")
      return_array  = ["first","last"]
      expect(userfile_name).to receive(:scan).and_return(return_array)
      expect(return_array).to receive(:last)
      Userfile.file_extension(userfile_name)
    end
  end

  describe "#self.valid_file_classes" do

    it "should return an array with current classe and all subclasses" do
      global_size = SingleFile.send(:descendants).size + 1
      expect(SingleFile.valid_file_classes.size).to eq(global_size)
    end
  end

  describe "#valid_file_classes" do

    it "should call class.valid_file_classes" do
      userfile_class = double("userfile")
      expect(userfile).to receive(:class).and_return(userfile_class)
      expect(userfile_class).to receive(:valid_file_classes).and_return([])
      userfile.valid_file_classes
    end
  end

  describe "#self.valid_file_types" do

    it "should call valid_file_classes.map" do
      userfile
      return_array  = ["class1","class2"]
      expect(Userfile).to receive(:valid_file_classes).and_return(return_array)
      expect(return_array).to receive(:map)
      Userfile.valid_file_types
    end
  end

  describe "#valid_file_types" do

    it "should call class.valid_file_types" do
      userfile_class = double("userfile")
      expect(userfile).to receive(:class).and_return(userfile_class)
      expect(userfile_class).to receive(:valid_file_types).and_return([])
      userfile.valid_file_types
    end
  end

  describe "#is_valid_file_type?(type)" do

    it "should call valid_file_types.include?" do
      return_array  = ["type1","type2"]
      expect(userfile).to receive(:valid_file_types).and_return(return_array)
      expect(return_array).to receive(:include?)
      userfile.is_valid_file_type?("type")
    end
  end

  describe "#suggested_file_type" do

    it "should call valid_file_classes.find" do
      return_array  = ["type1","type2"]
      expect(userfile).to receive(:valid_file_classes).and_return(return_array)
      expect(return_array).to receive(:find)
      userfile.suggested_file_type
    end
  end

  describe "#update_file_type" do
    before(:each) do
      allow(userfile).to receive(:save_with_logging)
    end

    it "should call is_valid_file_type" do
      expect(userfile).to receive(:is_valid_file_type?)
      userfile.update_file_type("type")
    end

    it "should save type if is_valid_file_type? return true" do
      allow(userfile).to receive(:is_valid_file_type?).and_return(true)
      userfile.update_file_type("new_type")
      expect(userfile.type).to eq("new_type")
    end

    it "should return false if is_valid_file_type? return false" do
      allow(userfile).to receive(:is_valid_file_type?).and_return(false)
      expect(userfile.update_file_type("new_type")).to be_falsey
    end
  end
  
  #Testing the get_tags_for_user method
  describe "#get_tags_for_user" do

    it "should return no tags when user and files has no tags" do
      expect(userfile.get_tags_for_user(userfile.user)).to be_empty
    end

    it "should return it's tags crossed with the user when get_tags_for_user(user) is called and the file has tags" do
      test_tag = create(:tag, :name => "test_tag", :user => userfile.user)
      userfile.tags << test_tag
      expect(userfile.get_tags_for_user(userfile.user).include?(test_tag)).to be true
    end

    it "should return no tags if the user has no tags in common with the userfile tags" do
       test_tag = create(:tag, :name => "test_tag")
       userfile.tags << test_tag
       expect(userfile.get_tags_for_user(userfile.user).include?(test_tag)).to be false
     end

     it "should set new tags when I call set_tags_for_user with new tags" do
       test_tag = create(:tag, :user => userfile.user)
       userfile.set_tags_for_user(userfile.user, [test_tag.id])
       expect(userfile.get_tags_for_user(userfile.user).include?(test_tag)).to be true
     end
   end

  describe "#set_tags_for_user" do
    let(:tag1) {create(:tag, :name => "tag_1")}
    let(:tag2) {create(:tag, :name => "tag_2")}
    let(:tag3) {create(:tag, :name => "tag_3")}

    it "should accept a nil for set_tags_for_user so no addition in tag_ids" do
      userfile.set_tags_for_user(userfile.user, nil)
      expect(userfile.tag_ids).to be_empty
    end

    it "should add tags arg to userfile.tag_ids if not already in userfile.tag_ids" do
      tag1; tag2; tag3;
      userfile.tag_ids = [tag1.id,tag2.id]
      userfile.set_tags_for_user(userfile.user, [tag3.id])
      expect(userfile.tag_ids).to match_array([tag1.id, tag2.id, tag3.id])
    end

    it "should not add tags arg to userfile.tag_ids if already in userfile.tag_ids" do
      tag1; tag2; tag3;
      userfile.tag_ids = [tag1.id,tag2.id]
      userfile.set_tags_for_user(userfile.user, [tag1.id])
      expect(userfile.tag_ids).to match_array([tag1.id,tag2.id])
    end
  end

  describe "#level" do

    it "should assigns 0 to @level" do
      expect(userfile.level).to eq(0)
    end

  end

  describe "#can_be_accessed_by?" do

    it "should return true if user is admin" do
      expect(userfile.can_be_accessed_by?(admin)).to be_truthy
     end

     it "should return true if user is site_manager of the site" do
       allow(userfile).to receive_message_chain(:user, :site_id).and_return(site_manager.site_id)
       allow(userfile).to receive_message_chain(:group, :site_id).and_return(site_manager.site_id)
       expect(userfile.can_be_accessed_by?(site_manager)).to be_truthy
     end

    it "should return true if user.id is same as self user.id" do
      user.id = userfile.user_id
      expect(userfile.can_be_accessed_by?(user)).to be_truthy
     end

     it "should return true if user is in a specific group and have good permission" do
       allow(user).to receive(:is_member_of_group).and_return(true)
       allow(userfile).to receive(:group_writable).and_return(true)
       expect(userfile.can_be_accessed_by?(user)).to be_truthy
     end

     it "should return true if user is in a specific group and request_access is read" do
       allow(user).to receive(:is_member_of_group).and_return(true)
       expect(userfile.can_be_accessed_by?(user, :read)).to be_truthy
     end

    it "should return false if all previous condition failed" do
      user.id = userfile.user_id + 1
      expect(userfile.can_be_accessed_by?(user)).to be_falsey
    end
  end

  describe "#has_owner_access?" do

    it "should return true if user is admin" do
      expect(userfile.has_owner_access?(admin)).to be_truthy
    end

    it "should return true if user is site_manager of the site" do
       allow(userfile).to receive_message_chain(:user, :site_id).and_return(site_manager.site_id)
       allow(userfile).to receive_message_chain(:group, :site_id).and_return(site_manager.site_id)
       expect(userfile.can_be_accessed_by?(site_manager)).to be_truthy
    end

    it "should return true if user is same as self user.id" do
      user.id = userfile.user_id
      expect(userfile.can_be_accessed_by?(user)).to be_truthy
    end

    it "should return false if all previous condition failed" do
      user.id = userfile.user_id + 1
      expect(userfile.can_be_accessed_by?(user)).to be_falsey
    end

  end

  describe "#self.accessible_for_user" do

    it "should call scoped with options" do
      userfile
      options = {}
      expect(Userfile).to receive(:scoped).with(options)
      allow(Userfile).to receive(:restrict_access_on_query)
      Userfile.accessible_for_user(user, options)
    end

    it "should call restrict_access_on_query" do
      userfile
      options = {}
      allow(Userfile).to receive(:scoped)
      expect(Userfile).to receive(:restrict_access_on_query).and_return("scope")
      expect(Userfile.accessible_for_user(user, options)).to eq("scope")
    end

  end

  describe "#self.find_accessible_by_user" do

    it "should call accessible_for_user" do
      userfile
      expect(Userfile).to receive(:accessible_for_user).and_return(Userfile)
      Userfile.find_accessible_by_user(userfile.id, user)
    end

  end

  describe "#find_all_accessible_by_user" do

    it "should call accessible_for_user" do
      userfile
      expect(Userfile).to receive(:accessible_for_user).and_return(Userfile)
      Userfile.find_all_accessible_by_user(user)
    end

  end

  describe "#self.restrict_access_on_query" do
    let!(:user1)     { create(:normal_user, :site_id => user.site_id) }
    let!(:group)     { create(:group)}
    let!(:userfile1) { create(:single_file, :user_id => site_manager.id, :group_id => group.id, :group_writable => true) }
    let!(:userfile2) { create(:single_file, :user_id => user.id,         :group_id => group.id, :data_provider_id => userfile1.data_provider_id, :group_writable => false) }
    let!(:userfile3) { create(:single_file, :user_id => user1.id,        :group_id => group.id, :data_provider_id => userfile1.data_provider_id) }

    before(:each) do
      allow(DataProvider).to receive_message_chain(:find_all_accessible_by_user, :raw_first_column).and_return([userfile1.data_provider_id])
    end

    it "should return scope if user is admin" do
      scope = Userfile.scoped({})
      expect(Userfile.restrict_access_on_query(admin, scope)).to eq(scope)
    end

    it "should return only file writable by user" do
      scope = Userfile.scoped({})
      expect(Userfile.restrict_access_on_query(site_manager,scope).all).to match_array([userfile1])
    end

    it "should return all file of user" do
      scope = Userfile.scoped({})
      expect(Userfile.restrict_access_on_query(user,scope, {:access_requested => "read"}).all).to match_array([userfile2])
    end

    it "should return file of all user and file where userfiles.group_id IN (?) AND userfiles.data_provider_id IN (?)" do
      scope = Userfile.scoped({})
      user.group_ids = user.group_ids << userfile1.group_id
      expect(Userfile.restrict_access_on_query(user,scope, {:access_requested => "read"}).all).to match_array([userfile1,userfile2,userfile3])
    end

    it "should return all file test site manager case" do
      user.site_id  = site_manager.site_id
      user1.site_id = site_manager.site_id
      allow(site_manager).to receive(:has_role?).and_return(true)
      scope = Userfile.scoped({})
      expect(Userfile.restrict_access_on_query(site_manager,scope).all).to match_array([userfile1, userfile2, userfile3])
    end

  end

  describe "#self.is_legal_filename?" do

    it "should return true if basename match with a specific pattern" do
      basename = double("basename")
      expect(basename).to receive(:match).and_return(true)
      expect(Userfile.is_legal_filename?(basename)).to be_truthy
    end

    it "return false if basename not match with specific pattern" do
      basename = double("basename")
      expect(basename).to receive(:match).and_return(false)
      expect(Userfile.is_legal_filename?(basename)).to be_falsey
    end
  end

  describe "list_files" do
    let(:data_provider) {create(:data_provider, :online => true, :read_only => false)}

    it "should call cache_collection_index if is_locally_cached? is true" do
      allow(userfile).to receive(:is_locally_cached?).and_return(true)
      expect(userfile).to receive(:cache_collection_index)
      userfile.list_files
    end

    it "should call provider_collection_index if is_locally_cached? is true" do
      userfile.data_provider = data_provider
      allow(userfile).to receive(:is_locally_cached?).and_return(false)
      expect(userfile).to receive(:provider_collection_index)
      userfile.list_files
    end
  end

  describe "#set_size" do
    it "should call set_size! if size is blank" do
      allow(userfile).to receive_message_chain(:size, :blank?).and_return(true)
      expect(userfile).to receive(:set_size!)
      userfile.set_size
    end
    it "should not call set_size! if size is not blank" do
      allow(userfile).to receive_message_chain(:size, :blank?).and_return(false)
      expect(userfile).not_to receive(:set_size!)
      userfile.set_size
    end

  end

  describe "#set_size!" do

    it "should always raise an error" do
      expect{userfile.set_size!}.to raise_error
    end
  end

  describe "#self.file_name_pattern" do

    it "should always return nil" do
      expect(Userfile.file_name_pattern).to eq(nil)
    end
  end



 describe "#self.pretty_type" do
    let(:mock_file) {mock_model(LogFile, :name => "log_file").as_null_object}


    it "should call name.gsub" do
      mock_file
      name = double("name")
      expect(LogFile).to receive(:name).and_return(name)
      expect(name).to receive(:gsub)
      LogFile.pretty_type
    end
  end


  describe "#pretty_type" do

    it "should call class.pretty_type" do
      userfile_class = double("userfile")
      expect(userfile).to receive(:class).and_return(userfile_class)
      expect(userfile_class).to receive(:pretty_type).and_return([])
      userfile.pretty_type
    end
  end

  describe "#move_to_child_of" do
    let(:userfile1) {create(:userfile)}

    it "should raise error if self.id == userfile.id" do
      expect{userfile.move_to_child_of(userfile)}.to raise_error
    end

    it "should raise error if self.descendants.include?(userfile)" do
      allow(userfile).to receive_message_chain(:descendants, :include?).and_return(true)
      expect{userfile.move_to_child_of(userfile1)}.to raise_error
    end

    it "should set parent.id to userfile.id if no error was raised" do
      allow(userfile).to receive_message_chain(:descendants, :include?).and_return(false)
      userfile.move_to_child_of(userfile1)
      expect(userfile.parent_id).to eq(userfile1.id)
    end

    it "should return true if all it's ok" do
      allow(userfile).to receive_message_chain(:descendants, :include?).and_return(false)
      expect(userfile.move_to_child_of(userfile1)).to be_truthy
    end

  end

  describe "#descendants" do

    it "should add this userfile's children to the list" do
      expect(userfile).to receive(:children).and_return([])
      userfile.descendants
    end

    it "it should add the childrens' descendents to the list" do
      child = mock_model(Userfile).as_null_object
      allow(userfile).to receive(:children).and_return([child])
      expect(child).to receive(:descendants).and_return([])
      userfile.descendants
    end

  end

  describe "#next_available_file" do
    let(:user) {create(:normal_user)}
    let(:userfile1) {create(:userfile, :user_id => user.id, :id => (userfile.id + 1).to_i)}
    let(:userfile2) {create(:userfile, :user_id => user.id, :id => (userfile.id + 2).to_i)}

    it "should return next available file" do
      userfile.user_id = user.id
      userfile1; userfile2
      expect(userfile.next_available_file(user).id).to eq(userfile1.id)
    end

    it "should return nil if no next available file" do
      userfile.user_id = user.id
      userfile1; userfile2
      expect(userfile2.next_available_file(user)).to be_nil
    end

  end

  describe "#previous_available_file" do
    let(:user) {mock_model(NormalUser)}

    it "should only check files available to the user" do
      expect(Userfile).to receive(:accessible_for_user).with(user, anything).and_return(double("files").as_null_object)
      userfile.previous_available_file(user).id
    end

    it "should return the last element it finds" do
      allow(Userfile).to receive_message_chain(:accessible_for_user, :order, :where).and_return(["file1", "file2"])
      expect(userfile.previous_available_file(user)).to eq("file2")
    end

  end

  describe "#provider_is_newer" do

    it "should call SyncStatus.ready_to_modify_dp" do
     expect(SyncStatus).to receive(:ready_to_modify_dp)
     userfile.provider_is_newer
    end

  end

  describe "#cache_is_newer" do

    it "should call SyncStatus.ready_to_modify_cache" do
     expect(SyncStatus).to receive(:ready_to_modify_cache)
     userfile.cache_is_newer
    end

  end

  describe "#local_sync_status" do

    it "should call Synctatus.where" do
      expect(SyncStatus).to receive(:where).and_return([1])
      userfile.local_sync_status
   end
  end

  describe "#is_locally_synced?" do

    let(:data_provider) {double("data_provider", :is_fast_syncing? => true, :not_syncable? => false, :rr_allowed_syncing? => true)}
    let(:syncstat) {double("syncstat", :status => "Other")}

    before(:each) do
      allow(userfile).to receive(:data_provider).and_return(data_provider)
      allow(userfile).to receive(:local_sync_status).and_return(syncstat)
      allow(userfile).to receive(:sync_to_cache)
    end

    it "should return true if status is InSync" do
      allow(syncstat).to receive(:status).and_return("InSync")
      expect(userfile.is_locally_synced?).to be_truthy
    end

    it "should return false if the data provider isn't fast syncing" do
      allow(data_provider).to receive(:is_fast_syncing?).and_return(false)
      expect(userfile.is_locally_synced?).to be_falsey
    end

    it "should return false if the data provider isn't syncablw" do
      allow(data_provider).to receive(:not_syncable?).and_return(true)
      expect(userfile.is_locally_synced?).to be_falsey
    end

    it "should return false if the data provider doesn't allow syncing" do
      allow(data_provider).to receive(:rr_allowed_syncing?).and_return(false)
      expect(userfile.is_locally_synced?).to be_falsey
    end

    it "should return true if after refresh status is InSync" do
      allow(syncstat).to receive(:status).and_return("Other", "InSync")
      expect(userfile.is_locally_synced?).to be_truthy
    end

    it "should return false in all other cases" do
      expect(userfile.is_locally_synced?).to be_falsey
    end
  end

  describe "#is_locally_cached?" do

    it "should return true if is_locally_synced" do
      allow(userfile).to receive(:is_locally_synced?).and_return(true)
      expect(userfile.is_locally_cached?).to be_truthy
    end

    it "should call local_sync_status" do
      allow(userfile).to receive(:is_locally_synced?).and_return(false)
      expect(userfile).to receive(:local_sync_status)
      userfile.is_locally_cached?
    end

    it "should return true if syncstat.status is CacheNewer" do
      syncstat = double("syncstat", :status => "CacheNewer")
      allow(userfile).to receive(:local_sync_status).and_return(syncstat)
      expect(userfile.is_locally_cached?).to be_truthy
    end
  end

  context "data provider easy acces methods" do

    let(:data_provider) {create(:data_provider, :online => true, :read_only => false)}

    describe "#sync_to_cache" do

      it "should call data_provider.sync_to_cache" do
        expect(userfile).to receive(:data_provider).and_return(data_provider)
        expect(data_provider).to receive(:sync_to_cache)
        userfile.sync_to_cache
      end
    end

    describe "#sync_to_provider" do

      it "should call data_provider.sync_to_provider" do
        expect(userfile).to receive(:data_provider).and_return(data_provider)
        expect(data_provider).to receive(:sync_to_provider)
        allow(userfile).to receive(:set_size!)
        userfile.sync_to_provider
      end
    end

    describe "#cache_erase" do

      it "should call data_provider.cache_erase" do
        expect(userfile).to receive(:data_provider).and_return(data_provider)
        expect(data_provider).to receive(:cache_erase)
        userfile.cache_erase
      end
    end

    describe "#cache_prepare" do
      let(:userfile1) {build(:userfile)}

      it "should call save if self.id.blank?" do
        expect(userfile1).to receive(:save!)
        allow(userfile1).to receive_message_chain(:data_provider,:cache_prepare)
        userfile1.cache_prepare
      end

      it "should call data_provider.cache_prepare" do
        expect(userfile).to receive(:data_provider).and_return(data_provider)
        expect(data_provider).to receive(:cache_prepare)
        userfile.cache_prepare
      end
    end

    describe "#cache_full_path" do

      it "should call data_provider.cache_full_path" do
        expect(userfile).to receive(:data_provider).and_return(data_provider)
        expect(data_provider).to receive(:cache_full_path)
        userfile.cache_full_path
      end
    end

    describe "#provider_erase" do

      it "should call data_provider.provider_erase" do
        expect(userfile).to receive(:data_provider).and_return(data_provider)
        expect(data_provider).to receive(:provider_erase)
        userfile.provider_erase
      end
    end

    describe "#provider_rename" do

      it "should call data_provider.provider_rename" do
        expect(userfile).to receive(:data_provider).and_return(data_provider)
        expect(data_provider).to receive(:provider_rename)
        userfile.provider_rename("newname")
      end
    end

    describe "#provider_move_to_otherprovider" do

      let(:data_provider_other) {create(:data_provider, :online => true, :read_only => false)}

      it "should call data_provider.provider_move_to_otherprovider" do
        expect(userfile).to receive(:data_provider).and_return(data_provider)
        expect(data_provider).to receive(:provider_move_to_otherprovider)
        userfile.provider_move_to_otherprovider(data_provider_other)
      end
    end

    describe "#provider_copy_to_otherprovider" do

      let(:data_provider_other) {create(:data_provider, :online => true, :read_only => false)}

      it "should call data_provider.provider_copy_to_otherprovider" do
        expect(userfile).to receive(:data_provider).and_return(data_provider)
        expect(data_provider).to receive(:provider_copy_to_otherprovider)
        userfile.provider_copy_to_otherprovider(data_provider_other)
      end
    end

    describe "#provider_collection_index" do

      it "should call data_provider.provider_collection_index" do
        expect(userfile).to receive(:data_provider).and_return(data_provider)
        expect(data_provider).to receive(:provider_collection_index)
        userfile.provider_collection_index
      end
    end

    describe "#provider_readhandle" do

      it "should call data_provider.provider_readhandle" do
        expect(userfile).to receive(:data_provider).and_return(data_provider)
        expect(data_provider).to receive(:provider_readhandle)
        userfile.provider_readhandle
      end

    end

    describe "#cache_readhandle" do

      it "should call data_provider.cache_readhandle" do
        expect(userfile).to receive(:data_provider).and_return(data_provider)
        expect(data_provider).to receive(:cache_readhandle)
        userfile.cache_readhandle
      end
    end

    describe "#cache_writehandle" do

      it "should call save!" do
        expect(userfile).to receive(:data_provider).and_return(data_provider)
        expect(data_provider).to receive(:cache_writehandle)
        allow(userfile).to receive(:set_size!)
        expect(userfile).to receive(:save!)
        userfile.cache_writehandle
      end

      it "should call data_provider.cache_writehandle" do
        expect(userfile).to receive(:data_provider).and_return(data_provider)
        expect(data_provider).to receive(:cache_writehandle)
        allow(userfile).to receive(:set_size!)
        userfile.cache_writehandle
      end

      it "should call set_size!" do
        expect(userfile).to receive(:data_provider).and_return(data_provider)
        allow(data_provider).to receive(:cache_writehandle)
        expect(userfile).to receive(:set_size!)
        userfile.cache_writehandle("filename")
      end
    end

    describe "#cache_copy_from_local_file" do

      it "should call save!" do
        expect(userfile).to receive(:data_provider).and_return(data_provider)
        expect(data_provider).to receive(:cache_copy_from_local_file)
        expect(userfile).to receive(:save!)
        allow(userfile).to receive(:set_size!)
        userfile.cache_copy_from_local_file("filename")
      end

      it "should call data_provider.cache_copy_from_local_file" do
        expect(userfile).to receive(:data_provider).and_return(data_provider)
        expect(data_provider).to receive(:cache_copy_from_local_file)
        allow(userfile).to receive(:set_size!)
        userfile.cache_copy_from_local_file("file_name")
      end

      it "should call set_size!" do
        expect(userfile).to receive(:data_provider).and_return(data_provider)
        expect(data_provider).to receive(:cache_copy_from_local_file)
        expect(userfile).to receive(:set_size!)
        userfile.cache_copy_from_local_file("filename")
      end

    end

    describe "#cache_copy_to_local_file" do

      it "should call save!" do
        expect(userfile).to receive(:data_provider).and_return(data_provider)
        expect(data_provider).to receive(:cache_copy_to_local_file)
        allow(userfile).to receive(:set_size!)
        expect(userfile).to receive(:save!)
        userfile.cache_copy_to_local_file("filename")
      end

      it "should call data_provider.cache_copy_to_local_file" do
        expect(userfile).to receive(:data_provider).and_return(data_provider)
        expect(data_provider).to receive(:cache_copy_to_local_file)
        userfile.cache_copy_to_local_file("filename")
      end

    end

    describe "#cache_collection_index" do

      it "should call data_provider.cache_collection_index" do
        data_provider = double("data_provider")
        expect(userfile).to receive(:data_provider).and_return(data_provider)
        expect(data_provider).to receive(:cache_collection_index)
        userfile.cache_collection_index
      end
    end

    describe "#available?" do

      it ".available? should return true if provider is online" do
        userfile.data_provider.online = true
        expect(userfile.available?).to be true
      end

      it ".available? should be false if provider is offline" do
        userfile.data_provider.online = false
        expect(userfile.available?).to be false
      end
    end
  end

end

