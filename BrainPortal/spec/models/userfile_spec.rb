
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

describe Userfile do
  let(:userfile) {Factory.create(:userfile)}
  let(:user) {Factory.create(:normal_user)}
  let(:site_manager) {Factory.create(:site_manager)}
  let(:admin) {Factory.create(:admin_user)}
  
  it "should be valid with valid attributes" do
    userfile.valid?.should be true
  end
  
  it "should require a name" do
    userfile.name = nil
    userfile.valid?.should be false
  end
  
  it "should require a user" do
    userfile.user = nil
    userfile.valid?.should be false
  end
  
  it "should require a group" do
    userfile.group = nil
    userfile.valid?.should be false
  end
  
  it "should require that the user has no other files with the same name in the same data_provider" do
    userfile.name = "abc"
    userfile.save
    bad_file=Factory.build( :userfile, :name => "abc",
                                       :user => userfile.user, 
                                       :data_provider => userfile.data_provider )
    bad_file.valid?.should be false
  end
  
  describe Userfile::Viewer do
    let(:viewer) {Userfile::Viewer.new({:name => "name", :partial => "partial"})}

    describe "#initialize" do
      
      it "should transform string into hash" do
        name = "name"
        viewer_test    = Userfile::Viewer.new(name)
        name_result    = name.to_s.classify.gsub(/(.+)([A-Z])/, '\1 \2')
        partial_result = name.to_s.underscore
        viewer_test.name.should    == name_result
        viewer_test.partial.should == partial_result 
      end
    end

    describe "#initialize_from_hash" do
      
      it "should return cbrain error if atts have no key name and no key partial" do
        lambda{viewer.initialize_from_hash({})}.should raise_error(CbrainError)
      end

      it "should return cbrain error if we have an unknow viewer" do
        lambda{viewer.initialize_from_hash({:name => "name", :partial => "partial", :other => "other"})}.should raise_error(CbrainError)
      end

      it "should raise cbrain error if condition does not respond_to :to_proc" do
        String.stub!(:respond_to?).and_return(false)
        lambda{viewer.initialize_from_hash({:name => "name", :partial => "partial", :if => "condition"})}.should raise_error(CbrainError)
      end
    end

    describe "#valid_for?" do
      let(:viewer_with_condition) {Userfile::Viewer.new({:name => "name", :partial => "partial", :if => lambda {|u| u.name == "userfile_name"}})}

      it "should return true if @conditions is empty" do
        Array.stub!(:empty?).and_return(true)
        viewer.valid_for?(userfile).should be_true
      end

      it "should call call on condition" do
        userfile.name = "userfile_name"
        viewer_with_condition.valid_for?(userfile).should be_true 
      end
    end
    
    describe "#==" do 
      let(:other1)  {Userfile::Viewer.new({:name => "name", :partial => "partial"})}
      let(:other2)  {Userfile::Viewer.new({:name => "other", :partial => "partial"})}
      
      it "should return false if other is not a Viewer" do
        viewer.==("other1").should be_false
      end

      it "should return true if Viewer have same name" do
        viewer.==(other1).should be_true
      end

      it "should return false if Viewer have different name" do
        viewer.==(other2).should be_false
      end
    end

  end
  
  describe "#viewers" do
    
    it "should call class.class_viewers" do
      userfile_class = double("userfile")
      userfile.should_receive(:class).and_return(userfile_class)
      userfile_class.should_receive(:class_viewers).and_return([])
      userfile.viewers
    end
  end

  describe "#find_viewer(name)" do

    it "should call viewers.find" do
      userfile_viewers = double(["viewer1","viewer2"])
      userfile.should_receive(:viewers).and_return(userfile_viewers)
      userfile_viewers.should_receive(:find).and_return([])
      userfile.find_viewer("viewer1")
    end
  end

  describe "#site" do
    
    it "should return the users site when site is called" do
      userfile.save
      userfile.site.should == userfile.user.site
    end
  end
  
  describe "#self.pseudo_sort_columns" do
    
    it "should return a pseudo array" do
      userfile
      Userfile.pseudo_sort_columns.should be == ["tree_sort"]
    end
  end

  describe "#file_extension" do
    
    it "should call class.file_extension" do
      userfile_class = double("userfile")
      userfile.should_receive(:class).and_return(userfile_class)
      userfile_class.should_receive(:file_extension)
      userfile.file_extension
    end
  end

  describe "#self.file_extension(name)" do

    it "should call scan and last on name" do
      userfile_name = double("name")
      return_array  = ["first","last"]
      userfile_name.should_receive(:scan).and_return(return_array)
      return_array.should_receive(:last)
      Userfile.file_extension(userfile_name)
    end
  end

  describe "#self.valid_file_classes" do
    
    it "should return an array with current classe and all subclasses" do
      global_size = SingleFile.send(:descendants).size + 1
      SingleFile.valid_file_classes.size.should be == global_size 
    end
  end

  describe "#valid_file_classes" do

    it "should call class.valid_file_classes" do
      userfile_class = double("userfile")
      userfile.should_receive(:class).and_return(userfile_class)
      userfile_class.should_receive(:valid_file_classes).and_return([])
      userfile.valid_file_classes
    end
  end

  describe "#self.valid_file_types" do

    it "should call valid_file_classes.map" do
      userfile
      return_array  = ["class1","class2"]
      Userfile.should_receive(:valid_file_classes).and_return(return_array)
      return_array.should_receive(:map)
      Userfile.valid_file_types
    end
  end

  describe "#valid_file_types" do

    it "should call class.valid_file_types" do
      userfile_class = double("userfile")
      userfile.should_receive(:class).and_return(userfile_class)
      userfile_class.should_receive(:valid_file_types).and_return([])
      userfile.valid_file_types
    end
  end

  describe "#is_valid_file_type?(type)" do

    it "should call valid_file_types.include?" do
      return_array  = ["type1","type2"]
      userfile.should_receive(:valid_file_types).and_return(return_array)
      return_array.should_receive(:include?)
      userfile.is_valid_file_type?("type")
    end
  end

  describe "#suggested_file_type" do

    it "should call valid_file_classes.find" do 
      return_array  = ["type1","type2"]
      userfile.should_receive(:valid_file_classes).and_return(return_array)
      return_array.should_receive(:find)  
      userfile.suggested_file_type
    end
  end

  describe "#update_file_type" do
    
    it "should call is_valid_file_type" do
      userfile.should_receive(:is_valid_file_type?)
      userfile.update_file_type("type")
    end

    it "should save type if is_valid_file_type? return true" do
      userfile.stub(:is_valid_file_type?).and_return(true)
      userfile.update_file_type("new_type")
      userfile.type.should be == "new_type"
    end

    it "should return false if is_valid_file_type? return false" do
      userfile.stub(:is_valid_file_type?).and_return(false)
      userfile.update_file_type("new_type").should be_false
    end
  end
  
  #Testing the format_size method
  describe "#format_size" do 
    it "should return unknown for the format_size when size is blank" do
      userfile.size = nil
      userfile.format_size.should match("unknown")
    end
  
    it "should return GB for format_size when the size is over 1GB" do
      userfile.size = 1000000000
      userfile.format_size.should match("1.0 Gb")
    end
  
    it "should return MB for format_size when the size is less than 1GB and more than 1MB" do
      userfile.size = 100000000
      userfile.format_size.should match("100.0 Mb")
    end
  
    it "should return KB for the format_size when the size is less than 1MB and more than 1KB" do
      userfile.size = 10000
      userfile.format_size.should match("10.0 Kb")
    end
  
    it "should return bytes for the format_size when the size is less than 1KB and more than 0" do
      userfile.size = 10
      userfile.format_size.should match("10 bytes")
    end
  end

   describe "#add_format" do
     let(:userfile1) {Factory.create(:userfile)}
     let(:userfile2) {Factory.create(:userfile)}

     it "should return an array containing all format_source" do
       userfile.add_format(userfile).inspect
       userfile.add_format(userfile2).size.should be == 2
     end
  end

  describe "#format_name" do
   
   it "should alweays return nil" do
     userfile.format_name.should be == nil
   end
  end

  describe "#format_names" do

    it "should call format_source" do
      userfile.should_receive(:format_source)
      userfile.format_names
    end

    it "should concatenate format_name and result of format.map" do
      userfile.stub!(:format_source).and_return(nil)
      userfile.stub!(:format_name).and_return(1)
      userfile.stub_chain(:formats, :map).and_return([2,3])
      userfile.format_names.should =~ [1,2,3]
    end
  end

  describe "#has_format?" do
    
    it "should return true if get_format return true" do
      userfile.stub!(:get_format).and_return(true)
      userfile.has_format?("format").should be_true
    end
    
    it "should return false if get_format return false" do
      userfile.stub!(:get_format).and_return(false)
      userfile.has_format?("format").should be_false
    end
  end

  describe "#get_format" do
    
    it "should return self if self.format_name.to_s.downcase == f.to_s.downcase" do
      f = double("format")
      f.stub_chain(:to_s, :downcase).and_return(f)
      userfile.stub_chain(:format_name, :to_s, :downcase).and_return(f)
      userfile.get_format(f).should be == userfile
    end
    
    it "should return self if self.class.name == f" do
      f = double("format")
      userfile.stub_chain(:class, :name).and_return(f) 
      userfile.get_format(f).should be == userfile
    end
    
    it "should call formats.all.find on self in other case" do
      f = double("format")
      userfile.should_receive(:formats).and_return(Userfile)
      userfile.get_format(f)
    end
    
  end
  
  #Testing the get_tags_for_user method
  describe "#get_tags_for_user" do
    
    it "should return no tags when user and files has no tags" do
      userfile.get_tags_for_user(userfile.user).should be_empty
    end
    
    it "should return it's tags crossed with the user when get_tags_for_user(user) is called and the file has tags" do
      test_tag = Factory.create(:tag, :name => "test_tag", :user => userfile.user)
      userfile.tags << test_tag
      userfile.get_tags_for_user(userfile.user).include?(test_tag).should be true
    end
    
    it "should return no tags if the user has no tags in common with the userfile tags" do
       test_tag = Factory.create(:tag, :name => "test_tag")
       userfile.tags << test_tag
       userfile.get_tags_for_user(userfile.user).include?(test_tag).should be false
     end
     
     it "should set new tags when I call set_tags_for_user with new tags" do
       test_tag = Factory.create(:tag, :user => userfile.user)
       userfile.set_tags_for_user(userfile.user, [test_tag.id])
       userfile.get_tags_for_user(userfile.user).include?(test_tag).should be true
     end
   end

  describe "#set_tags_for_user" do
    let(:tag1) {Factory.create(:tag, :id => 1, :name => "tag_1")}
    let(:tag2) {Factory.create(:tag, :id => 2, :name => "tag_2")}
    let(:tag3) {Factory.create(:tag, :id => 3, :name => "tag_3")}
    
    it "should accept a nil for set_tags_for_user so no addition in tag_ids" do
      userfile.set_tags_for_user(userfile.user, nil)
      userfile.tag_ids.should be_empty
    end
    
    it "should add tags arg to userfile.tag_ids if not already in userfile.tag_ids" do
      tag1; tag2; tag3;
      userfile.tag_ids = [1,2]
      userfile.set_tags_for_user(userfile.user, [3])
      userfile.tag_ids.should =~ [1,2,3]
    end
    
    it "should not add tags arg to userfile.tag_ids if already in userfile.tag_ids" do
      tag1; tag2; tag3;
      userfile.tag_ids = [1,2]
      userfile.set_tags_for_user(userfile.user, [1])
      userfile.tag_ids.should =~ [1,2]
    end 
  end

  describe "#self.tree_sort" do
    let(:userfile1) {Factory.create(:userfile, :parent_id => userfile.id)}
    let(:userfile2) {Factory.create(:userfile, :parent_id => userfile1.id)}
    let(:userfile3) {Factory.create(:userfile, :parent_id => userfile2.id)}
    let(:userfile4) {Factory.create(:userfile)}
    let(:userfile5) {Factory.create(:userfile, :parent_id => userfile4.id)}
    
    it "should return sorted tree" do
      Userfile.tree_sort([userfile, userfile2, userfile3, userfile1]).should be == 
        [userfile, userfile1, userfile2, userfile3]
    end

    it "should return sorted tree" do
      Userfile.tree_sort([userfile5, userfile, userfile2, userfile3, userfile1,userfile4]).should be ==
        [userfile, userfile1, userfile2, userfile3, userfile4, userfile5]
    end

    it "should assign level for each userfiles" do
      Userfile.tree_sort([userfile5, userfile, userfile2, userfile3, userfile1,userfile4])
      userfile.level.should be  == 0
      userfile1.level.should be == 1
      userfile2.level.should be == 2
      userfile3.level.should be == 3
      userfile4.level.should be == 0
      userfile5.level.should be == 1
    end
    
  end

  describe "#level" do
    
    it "should assigns 0 to @level" do
      userfile.level.should be == 0 
    end

  end

  describe "#can_be_accessed_by?" do
   
    it "should return true if user is admin" do
      userfile.can_be_accessed_by?(admin).should be_true
     end
     
     it "should return true if user is site_manager of the site" do
       userfile.stub_chain(:user, :site_id).and_return(site_manager.site_id)
       userfile.stub_chain(:group, :site_id).and_return(site_manager.site_id)
       userfile.can_be_accessed_by?(site_manager).should be_true
     end
   
    it "should return true if user.id is same as self user.id" do
      user.id = userfile.user_id
      userfile.can_be_accessed_by?(user).should be_true
     end
   
     it "should return true if user is in a specific group and have good permission" do
       user.stub!(:is_member_of_group).and_return(true)
       userfile.stub!(:group_writable).and_return(true)
       userfile.can_be_accessed_by?(user).should be_true
     end

     it "should return true if user is in a specific group and request_access is read" do
       user.stub!(:is_member_of_group).and_return(true)
       userfile.can_be_accessed_by?(user, :read).should be_true
     end
     
    it "should return false if all previous condition failed" do
      user.id = userfile.user_id + 1
      userfile.can_be_accessed_by?(user).should be_false
    end
  end

  describe "#has_owner_access?" do
  
    it "should return true if user is admin" do
      userfile.has_owner_access?(admin).should be_true
    end

    it "should return true if user is site_manager of the site" do
       userfile.stub_chain(:user, :site_id).and_return(site_manager.site_id)
       userfile.stub_chain(:group, :site_id).and_return(site_manager.site_id)
       userfile.can_be_accessed_by?(site_manager).should be_true
    end
    
    it "should return true if user is same as self user.id" do
      user.id = userfile.user_id
      userfile.can_be_accessed_by?(user).should be_true
    end
  
    it "should return false if all previous condition failed" do
      user.id = userfile.user_id + 1
      userfile.can_be_accessed_by?(user).should be_false
    end
 
  end

  describe "#self.accessible_for_user" do
                                
    it "should call scoped with options" do
      userfile
      options = {}
      Userfile.should_receive(:scoped).with(options)
      Userfile.stub!(:restrict_access_on_query)
      Userfile.accessible_for_user(user, options)
    end

    it "should call restrict_access_on_query" do
      userfile
      options = {}
      Userfile.stub!(:scoped)
      Userfile.should_receive(:restrict_access_on_query).and_return("scope")
      Userfile.accessible_for_user(user, options).should be == "scope"
    end
  
  end
  
  describe "#self.find_accessible_by_user" do

    it "should call accessible_for_user" do
      userfile
      Userfile.should_receive(:accessible_for_user).and_return(Userfile)
      Userfile.find_accessible_by_user(userfile.id, user)
    end
    
  end

  describe "#find_all_accessible_by_user" do
    
    it "should call accessible_for_user" do
      userfile
      Userfile.should_receive(:accessible_for_user).and_return(Userfile)
      Userfile.find_all_accessible_by_user(user)
    end
    
  end

  describe "#self.restrict_access_on_query" do
    let!(:user1)     {Factory.create(:normal_user, :site_id => user.site_id)}
    let!(:userfile1) {Factory.create(:userfile, :user_id => user.id, :group_writable => true)}
    let!(:userfile2) {Factory.create(:userfile, :user_id => user.id, :group_writable => false)}
    let!(:userfile3) {Factory.create(:userfile, :user_id => user1.id)}
    let!(:userfile4) {Factory.create(:userfile)}
    
    it "should return scope if user is admin" do
      scope = Userfile.scoped({})
      Userfile.restrict_access_on_query(admin,scope).should be == scope
    end

    it "should return only file writable by user" do
      scope = Userfile.scoped({})
      Userfile.restrict_access_on_query(site_manager,scope).all.should be =~ [userfile1]
    end

    it "should return all file of user" do
      scope = Userfile.scoped({})
      Userfile.restrict_access_on_query(user,scope, {:access_requested => "read"}).all.should be =~ [userfile1,userfile2]
    end

    it "should return file of all user and file where userfiles.group_id IN (?) AND userfiles.data_provider_id IN (?)" do
      scope = Userfile.scoped({})
      DataProvider.stub_chain(:find_all_accessible_by_user, :map).and_return([userfile3.data_provider_id])     
      Userfile.restrict_access_on_query(user,scope, {:access_requested => "read"}).all.should be =~ [userfile1,userfile2,userfile3]
    end

    it "should return all file test site manager case" do
      scope = Userfile.scoped({})
      Userfile.restrict_access_on_query(site_manager,scope).all.should be =~ [userfile1, userfile2, userfile3]
    end 
    
  end

  describe "#self.is_legal_filename?" do
    
    it "should return true if basename match with a specific pattern" do
      basename = double("basename")
      basename.should_receive(:match).and_return(true)
      Userfile.is_legal_filename?(basename).should be_true
    end

    it "return false if basename not match with specific pattern" do
      basename = double("basename")
      basename.should_receive(:match).and_return(false)
      Userfile.is_legal_filename?(basename).should be_false
    end 
  end

  describe "list_files" do
    let(:data_provider) {Factory.create(:data_provider, :online => true, :read_only => false)}

    it "should call cache_collection_index if is_locally_cached? is true" do
      userfile.stub!(:is_locally_cached?).and_return(true)
      userfile.should_receive(:cache_collection_index)
      userfile.list_files
    end
    
    it "should call provider_collection_index if is_locally_cached? is true" do
      userfile.data_provider = data_provider
      userfile.stub!(:is_locally_cached?).and_return(false)
      userfile.should_receive(:provider_collection_index)
      userfile.list_files
    end
  end

  describe "#set_size" do
    it "should call set_size! if size is blank" do
      userfile.stub_chain(:size, :blank?).and_return(true)
      userfile.should_receive(:set_size!)
      userfile.set_size
    end
    it "should not call set_size! if size is not blank" do 
      userfile.stub_chain(:size, :blank?).and_return(false)
      userfile.should_not_receive(:set_size!)
      userfile.set_size
    end
    
  end

  describe "#set_size!" do
    
    it "should always raise an error" do
      lambda{userfile.set_size!}.should raise_error
    end
  end

  describe "#self.file_name_pattern" do

    it "should always return nil" do
      Userfile.file_name_pattern.should be == nil
    end
  end

  describe "#self.pretty_type" do

    it "should call name.gsub" do
      userfile
      name = double("name")
      Userfile.should_receive(:name).and_return(name)
      name.should_receive(:gsub)
      Userfile.pretty_type
    end
  end

  describe "#pretty_type" do

    it "should call class.pretty_type" do
      userfile_class = double("userfile")
      userfile.should_receive(:class).and_return(userfile_class)
      userfile_class.should_receive(:pretty_type).and_return([])
      userfile.pretty_type
    end
  end

  describe "#move_to_child_of" do
    let(:userfile1) {Factory.create(:userfile)}
    
    it "should raise error if self.id == userfile.id" do
      lambda{userfile.move_to_child_of(userfile)}.should raise_error 
    end

    it "should raise error if self.descendants.include?(userfile)" do
      userfile.stub_chain(:descendants, :include?).and_return(true)
      lambda{userfile.move_to_child_of(userfile1)}.should raise_error
    end 

    it "should set parent.id to userfile.id if no error was raised" do
      userfile.stub_chain(:descendants, :include?).and_return(false)
      userfile.move_to_child_of(userfile1)
      userfile.parent_id.should be == userfile1.id
    end

    it "should return true if all it's ok" do
      userfile.stub_chain(:descendants, :include?).and_return(false)
      userfile.move_to_child_of(userfile1).should be_true
    end
  
  end

  describe "#descendants" do
    let(:userfile1) {Factory.create(:userfile, :parent_id => userfile.id)}
    let(:userfile2) {Factory.create(:userfile, :parent_id => userfile1.id)}
    let(:userfile3) {Factory.create(:userfile, :parent_id => userfile2.id)}
    let(:userfile4) {Factory.create(:userfile, :parent_id => userfile2.id)}
    
    it "should return descendants if it have descendants" do
      userfile; userfile1; userfile2; userfile3
      userfile1.descendants().should be =~ [userfile2, userfile3, userfile4]
    end

    it "should return empty array if it have not descendants" do
      userfile; userfile1; userfile2; userfile3
      userfile3.descendants().should be_empty
    end
    
  end

  describe "#next_available_file" do
    let(:user) {Factory.create(:normal_user)}
    let(:userfile1) {Factory.create(:userfile, :user_id => user.id, :id => (userfile.id + 1).to_i)}
    let(:userfile2) {Factory.create(:userfile, :user_id => user.id, :id => (userfile.id + 2).to_i)}

    it "should return next available file" do
      userfile.user_id = user.id
      userfile1; userfile2
      userfile.next_available_file(user).should be == userfile1
    end

    it "should return nil if no next available file" do
      userfile.user_id = user.id
      userfile1; userfile2
      userfile2.next_available_file(user).should be_nil
    end
    
  end

  describe "#previous_available_file" do
    let(:user) {Factory.create(:normal_user)}
    let(:userfile1) {Factory.create(:userfile, :user_id => user.id, :id => (userfile.id - 1).to_i)}
    let(:userfile2) {Factory.create(:userfile, :user_id => user.id, :id => (userfile.id - 2).to_i)}

    it "should return next available file" do
      userfile.user_id = user.id
      userfile1; userfile2
      userfile.previous_available_file(user).should be == userfile1
    end

    it "should return nil if no previous available file" do
      userfile.user_id = user.id
      userfile1; userfile2
      userfile2.previous_available_file(user).should be_nil
    end
    
  end

  describe "#provider_is_newer" do
    
    it "should call SyncStatus.ready_to_modify_dp" do
     SyncStatus.should_receive(:ready_to_modify_dp)
     userfile.provider_is_newer
    end
    
  end

  describe "#cache_is_newer" do

    it "should call SyncStatus.ready_to_modify_cache" do
     SyncStatus.should_receive(:ready_to_modify_cache)
     userfile.cache_is_newer
    end
    
  end

  describe "#local_sync_status" do
    
    it "should call Synctatus.where" do
      SyncStatus.should_receive(:where).and_return([1])
      userfile.local_sync_status
   end
  end

  describe "#is_locally_synced?" do
    
    it "should return true if status is InSync" do
      syncstat = double("syncstat", :status => "InSync")
      userfile.should_receive(:local_sync_status).any_number_of_times.and_return(syncstat)
      userfile.is_locally_synced?.should be_true
    end
    
    it "should return false if is fast syncing" do
      syncstat = double("syncstat", :status => "Other")
      userfile.should_receive(:local_sync_status).any_number_of_times.and_return(syncstat)
      userfile.stub_chain(:data_provider, :is_fast_syncing?).and_return(false)
      userfile.is_locally_synced?.should be_false
    end
    
    it "should return true if after refresh status is InSync" do
      syncstat = double("syncstat", :status => "Other")
      userfile.should_receive(:local_sync_status).any_number_of_times.and_return(syncstat)
      userfile.stub_chain(:data_provider, :is_fast_syncing?).and_return(true)
      userfile.stub!(:sync_to_cache)
      syncstat.stub!(:status).and_return("InSync")
      userfile.is_locally_synced?.should be_true
    end
    
    it "should return false in all other case" do
      syncstat = double("syncstat", :status => "Other")
      userfile.should_receive(:local_sync_status).any_number_of_times.and_return(syncstat)
      userfile.stub_chain(:data_provider, :is_fast_syncing?).and_return(true)
      userfile.stub!(:sync_to_cache)
      userfile.is_locally_synced?.should be_false
    end
  end

  describe "#is_locally_cached?" do

    it "should return true if is_locally_synced" do
      userfile.stub!(:is_locally_synced?).and_return(true)
      userfile.is_locally_cached?.should be_true
    end

    it "should call local_sync_status" do
      userfile.stub!(:is_locally_synced?).and_return(false)
      userfile.should_receive(:local_sync_status)
      userfile.is_locally_cached?
    end

    it "should return true if syncstat.status is CacheNewer" do
      syncstat = double("syncstat", :status => "CacheNewer")
      userfile.should_receive(:local_sync_status).any_number_of_times.and_return(syncstat)
      userfile.is_locally_cached?.should be_true
    end
  end

  context "data provider easy acces methods" do

    let(:data_provider) {Factory.create(:data_provider, :online => true, :read_only => false)}

    describe "#sync_to_cache" do
      
      it "should call data_provider.sync_to_cache" do
        userfile.should_receive(:data_provider).and_return(data_provider)
        data_provider.should_receive(:sync_to_cache)
        userfile.sync_to_cache
      end
    end

    describe "#sync_to_provider" do
      
      it "should call data_provider.sync_to_provider" do
        userfile.should_receive(:data_provider).and_return(data_provider)
        data_provider.should_receive(:sync_to_provider)
        userfile.stub!(:set_size!)
        userfile.sync_to_provider
      end
    end
  
    describe "#cache_erase" do
      
      it "should call data_provider.cache_erase" do
        userfile.should_receive(:data_provider).and_return(data_provider)
        data_provider.should_receive(:cache_erase)
        userfile.cache_erase
      end
    end
  
    describe "#cache_prepare" do
      let(:userfile1) {Factory.build(:userfile)}

      it "should call save if self.id.blank?" do
        userfile1.should_receive(:save!)
        userfile1.stub_chain(:data_provider,:cache_prepare)
        userfile1.cache_prepare
      end
      
      it "should call data_provider.cache_prepare" do
        userfile.should_receive(:data_provider).and_return(data_provider)
        data_provider.should_receive(:cache_prepare)
        userfile.cache_prepare
      end
    end
  
    describe "#cache_full_path" do
      
      it "should call data_provider.cache_full_path" do
        userfile.should_receive(:data_provider).and_return(data_provider)
        data_provider.should_receive(:cache_full_path)
        userfile.cache_full_path
      end
    end
  
    describe "#provider_erase" do
      
      it "should call data_provider.provider_erase" do
        userfile.should_receive(:data_provider).and_return(data_provider)
        data_provider.should_receive(:provider_erase)
        userfile.provider_erase
      end
    end
  
    describe "#provider_rename" do
      
      it "should call data_provider.provider_rename" do
        userfile.should_receive(:data_provider).and_return(data_provider)
        data_provider.should_receive(:provider_rename)
        userfile.provider_rename("newname")
      end
    end
  
    describe "#provider_move_to_otherprovider" do

      let(:data_provider_other) {Factory.create(:data_provider, :online => true, :read_only => false)}

      it "should call data_provider.provider_move_to_otherprovider" do
        userfile.should_receive(:data_provider).and_return(data_provider)
        data_provider.should_receive(:provider_move_to_otherprovider)
        userfile.provider_move_to_otherprovider(data_provider_other)
      end
    end
    
    describe "#provider_copy_to_otherprovider" do

      let(:data_provider_other) {Factory.create(:data_provider, :online => true, :read_only => false)}

      it "should call data_provider.provider_copy_to_otherprovider" do
        userfile.should_receive(:data_provider).and_return(data_provider)
        data_provider.should_receive(:provider_copy_to_otherprovider)
        userfile.provider_copy_to_otherprovider(data_provider_other)
      end
    end
  
    describe "#provider_collection_index" do
      
      it "should call data_provider.provider_collection_index" do
        userfile.should_receive(:data_provider).and_return(data_provider)
        data_provider.should_receive(:provider_collection_index)
        userfile.provider_collection_index
      end
    end
  
    describe "#provider_readhandle" do
      
      it "should call data_provider.provider_readhandle" do
        userfile.should_receive(:data_provider).and_return(data_provider)
        data_provider.should_receive(:provider_readhandle)
        userfile.provider_readhandle
      end
    
    end
  
    describe "#cache_readhandle" do
      
      it "should call data_provider.cache_readhandle" do
        userfile.should_receive(:data_provider).and_return(data_provider)
        data_provider.should_receive(:cache_readhandle)
        userfile.cache_readhandle
      end
    end
  
    describe "#cache_writehandle" do
      
      it "should call save!" do
        userfile.should_receive(:data_provider).and_return(data_provider)
        data_provider.should_receive(:cache_writehandle)
        userfile.stub!(:set_size!)
        userfile.should_receive(:save!)
        userfile.cache_writehandle
      end
      
      it "should call data_provider.cache_writehandle" do
        userfile.should_receive(:data_provider).and_return(data_provider)
        data_provider.should_receive(:cache_writehandle)
        userfile.stub!(:set_size!)
        userfile.cache_writehandle
      end
      
      it "should call set_size!" do
        userfile.should_receive(:data_provider).and_return(data_provider)
        data_provider.stub!(:cache_writehandle)
        userfile.should_receive(:set_size!)
        userfile.cache_writehandle("filename")
      end
    end
  
    describe "#cache_copy_from_local_file" do
      
      it "should call save!" do
        userfile.should_receive(:data_provider).and_return(data_provider)
        data_provider.should_receive(:cache_copy_from_local_file)
        userfile.should_receive(:save!)
        userfile.stub!(:set_size!)
        userfile.cache_copy_from_local_file("filename")
      end
      
      it "should call data_provider.cache_copy_from_local_file" do
        userfile.should_receive(:data_provider).and_return(data_provider)
        data_provider.should_receive(:cache_copy_from_local_file)
        userfile.stub!(:set_size!)
        userfile.cache_copy_from_local_file("file_name")
      end
      
      it "should call set_size!" do
        userfile.should_receive(:data_provider).and_return(data_provider)
        data_provider.should_receive(:cache_copy_from_local_file)
        userfile.should_receive(:set_size!)
        userfile.cache_copy_from_local_file("filename")
      end
    
    end

    describe "#cache_copy_to_local_file" do
        
      it "should call save!" do
        userfile.should_receive(:data_provider).and_return(data_provider)
        data_provider.should_receive(:cache_copy_to_local_file)
        userfile.stub!(:set_size!)
        userfile.should_receive(:save!)
        userfile.cache_copy_to_local_file("filename")
      end
  
      it "should call data_provider.cache_copy_to_local_file" do
        userfile.should_receive(:data_provider).and_return(data_provider)
        data_provider.should_receive(:cache_copy_to_local_file)
        userfile.cache_copy_to_local_file("filename")
      end
    
    end
    
    describe "#cache_collection_index" do
  
      it "should call data_provider.cache_collection_index" do
        data_provider = double("data_provider")
        userfile.should_receive(:data_provider).and_return(data_provider)
        data_provider.should_receive(:cache_collection_index)
        userfile.cache_collection_index
      end
    end
    
    describe "#available?" do 
  
      it ".available? should return true if provider is online" do
        userfile.data_provider.online = true
        userfile.available?.should be true
      end
    
      it ".available? should be false if provider is offline" do
        userfile.data_provider.online = false
        userfile.available?.should be false
      end
    end
  end
    
end

