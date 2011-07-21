#
# CBRAIN Project
#
# Userfile spec
#
# Original author: Nicolas Kassis
#
# $Id$
#

require 'spec_helper'

describe Userfile do
  let(:userfile) {Factory.create(:userfile)}
  
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
#----
  context "Class Viewer" do
  
    describe "#initialize" do
    end

    describe "#initialize_from_hash" do
    end

    describe "#valid_for?" do
    end

    describe "==" do
    end
  end

#----
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
    
    it "should return a pesudo array" do
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
      global_size = SingleFile.send(:subclasses).size + 1
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
      userfile.format_size.should match("1.0 GB")
    end
  
    it "should return MB for format_size when the size is less than 1GB and more than 1MB" do
      userfile.size = 100000000
      userfile.format_size.should match("100.0 MB")
    end
  
    it "should return KB for the format_size when the size is less than 1MB and more than 1KB" do
      userfile.size = 10000
      userfile.format_size.should match("10.0 KB")
    end
  
    it "should return bytes for the format_size when the size is less than 1KB and more than 0" do
      userfile.size = 10
      userfile.format_size.should match("10 bytes")
    end
  end

   describe "#add_format" do
     let(:userfile1) {Factory.create(:userfile)}
     let(:userfile2) {Factory.create(:userfile)}

     it "To check"
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

    it "should call formats.map.push.compact on source_file" do
      pending
      "Voir si appeller su format)source ou self"
      source_file = double("source_file")
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
    
    it "should call formats.all.find on self in other case"
  end
  
  #Testing the get_tags_for_user method
  describe "#get_tags_for_user" do
    
    it "should return no tags when user and files has no tags" do
      userfile.get_tags_for_user(userfile.user)
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
    it "should accept a nil for set_tags_for_user" do
      begin
        userfile.set_tags_for_user(userfile.user, nil)
      rescue
        false
      end
    end
  end

  describe "#self.tree_sort" do
  end

  describe "#all_tree_children" do
  end

  describe "#level" do
  end

  describe "#self.paginate" do
  end

  describe "#self.apply_tag_filters_for_user" do
  end

  describe "#self.get_filter_name" do

    it "should return nil if type is name_search term.blank? is false"
    
    it "should return nil if type is name_search term.blank? is false"
    
    it "should return nil if type is name_search term.blank? is false"

    it "should return nil if type is name_search term.blank? is true"

    it "should return nil if type is tag_search term.blank? is true"
    
    it "should return nil if type is format_search term.blank? is true"

    it "should return file:cw5"

    it "should return file:flt"

    it "should return file:mls"

    it "should return nil if no case is good"
  
  end

  describe "#self.add_filters_to_scope" do
  end

  describe "#can_be_accessed_by?" do
    let(:user) {Factory.create(:user)}
   
    it "should return true if user is admin" do
      user.role = "admin"
      userfile.can_be_accessed_by?(user).should be_true
     end
     
    it "should return true if user is site_manager of the site" 
   
    it "should return true if user.id is same as self user.id" do
      user.id = userfile.user_id
      userfile.can_be_accessed_by?(user).should be_true
     end
   
     it "should return true if user is in a specific group and have good permission" do
       user.stub_chain(:group_ids, :include?).and_return(true)
       userfile.stub!(:group_writable).and_return(true)
       userfile.can_be_accessed_by?(user).should be_true
     end

     it "should return true if user is in a specific group and request_access is read" do
       user.stub_chain(:group_ids, :include?).and_return(true)
       userfile.can_be_accessed_by?(user,:read).should be_true
     end
     
    it "should return false if all previous condition failed" do
      user.id = userfile.user_id + 1
      user.role = "other"
      userfile.can_be_accessed_by?(user).should be_false
    end
  end

  describe "#has_owner_access?" do
  
    let(:user) {Factory.create(:user)}
  
    it "should return true if user is admin" do
      user.role = "admin"
      userfile.has_owner_access?(user).should be_true
    end

    it "should return true if user is site_manager of the site" 

    it "should return true if user is same as self user.id" do
      user.id = userfile.user_id
      userfile.can_be_accessed_by?(user).should be_true
    end
  
    it "should return false if all previous condition failed" do
      user.id = userfile.user_id + 1
      user.role = "other"
      userfile.can_be_accessed_by?(user).should be_false
    end
  end

  describe "#self.find_accessible_by_user" do
  end

  describe "#self.find_all_accessible_by_user" do
  end

  describe "#self.restrict_access_on_query" do
  end

  describe "#self.restrict_site_on_query" do
  end

  describe "#self.set_order" do
    it "Check if no more used"
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
    it "should call set_size! if size is blank"
    it "should not call set_size! if size is not blank"
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
  end

  describe "#descendants" do
  end

  describe "#next_available_file" do
  end

  describe "#previous_available_file" do
  end

  describe "#provider_is_newer" do
    
    it "should call SyncStatus.ready_to_modify_dp" do
     SyncStatus.should_receive(:ready_to_modify_dp)
     userfile.provider_is_newer
    end
    
    it "return true if SyncStatus.ready_to_modify_dp return a non empty array" do
      SyncStatus.stub!(:ready_to_modify_dp).and_return([1])
      userfile.provider_is_newer.should be_true
    end

    it "should be verified"
    it "return nil if SyncStatus.ready_to_modify_dp return nil" do
      SyncStatus.stub!(:ready_to_modify_dp).and_return(nil)
      userfile.provider_is_newer.should be == nil
    end
  end

  describe "#cache_is_newer" do

    it "should call SyncStatus.ready_to_modify_cache" do
     SyncStatus.should_receive(:ready_to_modify_cache)
     userfile.cache_is_newer
    end
    
    it "return true if SyncStatus.ready_to_modify_cache return a non empty array" do
      SyncStatus.stub!(:ready_to_modify_cache).and_return([1])
      userfile.cache_is_newer.should be_true
    end

    it "should be verified"
    it "return nil if SyncStatus.ready_to_modify_cache return nil" do
      SyncStatus.stub!(:ready_to_modify_cache).and_return(nil)
      userfile.cache_is_newer.should be == nil
    end
  end

  describe "#local_sync_status" do
    
    it "should call Synctatus.find" do
     SyncStatus.should_receive(:find)
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
      
      it "should call save if self.id.blank?"
      
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
      
      it "should call save!"
      
      it "should call data_provider.cache_writehandle" do
        userfile.should_receive(:data_provider).and_return(data_provider)
        data_provider.should_receive(:cache_writehandle)
        userfile.stub!(:set_size!)
        userfile.cache_writehandle
      end
      
      it "should call set_size!"
    end
  
    describe "#cache_copy_from_local_file" do
      it "should call save!"
      
      it "should call data_provider.cache_copy_from_local_file" do
        userfile.should_receive(:data_provider).and_return(data_provider)
        data_provider.should_receive(:cache_copy_from_local_file)
        userfile.stub!(:set_size!)
        userfile.cache_copy_from_local_file("file_name")
      end
      
      it "should call set_size!"
    end
  
    describe "#cache_copy_to_local_file" do
        
      it "should call save!" 
  
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
  
    describe "#content" do
      
      it "should always return false" do
        userfile.content([]).should be_false
      end
    end
  end
    
end
