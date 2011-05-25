#
# CBRAIN Project
#
# DataProvider spec
#
# Original author: Nicolas Kassis
#
# $Id$
#


require 'spec_helper'

describe DataProvider do
  
  let(:provider) { Factory.create(:data_provider, :online => true, :read_only => false) }
  
  let(:userfile) do
    u = double("userfile")
    u.stub!(:name).and_return("userfile_double") 
    u.stub!(:id).and_return(123)
    u
  end
  
  describe "validations" do
    it "should create a new instance given valid attributes" do
      provider.valid?.should be(true)
    end

    it "should not save with a blank name" do
      provider.name = nil
      provider.valid?.should be(false)
    end

    it "should not save with no owner" do
      provider.user = nil
      provider.valid?.should be(false)
    end

    it "should not save with no group" do 
      provider.group =nil
      provider.valid?.should be(false)
    end

    it "should not accept a dp without a value for read_only" do
      provider.read_only = nil
      provider.valid?.should be(false)
    end

    it "should accept read_only being false" do
      provider.read_only = false
      provider.valid?.should be true
    end

    it "should accept read_only being true" do 
      provider.read_only = true
      provider.valid?.should be true
    end

    it "should not accept a name with invalid chars" do 
      provider.name = "*@$%"
      provider.valid?.should be(false)
    end

    it "should not accept a remote_host with invalid chars" do 
      provider.remote_host = "*@$%"
      provider.valid?.should be(false)
    end


    it "should not accept a remote_user with invalid chars" do 
      provider.remote_user = "*@$%"
      provider.valid?.should be(false)
    end


    it "should not have a remote_dir path with invalid characters" do
      provider.remote_dir = "*?$@"
      provider.valid?.should be(false)
    end
  end
  
  describe DataProvider::FileInfo do
    let(:file_info) {DataProvider::FileInfo.new}
    
    describe "#depth" do
      it "should calculate the depth of the userfile" do
        file_info.name = "/x/y/z"
        file_info.depth.should == 3
      end  
      it "should raise an exception if no name is given" do
        file_info.name = ""
        lambda{file_info.depth}.should raise_error(CbrainError, "File doesn't have a name.")
      end
    end
  end
  
  describe "#is_alive" do
     it "should return false when is_alive? is called on offline provider" do
       provider.online = false
       provider.is_alive?.should be(false)
    end
     
    it "should raise an exception if called but not implemented in a subclass" do 
      lambda{provider.is_alive?}.should raise_error("Error: method not yet implemented in subclass.")
    end
   
    it "should return false if impl_is_alive? returns false" do
      provider.stub!(:impl_is_alive?).and_return(false)
      provider.online = true
      provider.is_alive?.should be(false)
    end
   
    it "should raise and exception when is_alive! is called with an offline provider" do
      provider.online = false
      lambda{provider.is_alive!}.should raise_error
    end
  end
  
  describe "#is_browsable" do
    specify { provider.is_browsable?.should be_false}
  end
  
  describe "#is_fast_syncing?" do
    specify { provider.is_fast_syncing?.should be_false}
  end
   
  describe "#allow_file_owner_change?" do
    specify { provider.allow_file_owner_change?.should be_false}
  end
   
  describe "#sync_to_cache" do
    it "should raise an exception if not online" do
      provider.online = false
      lambda{provider.sync_to_cache(userfile)}.should raise_error(CbrainError, "Error: provider #{provider.name} is offline.")
    end
    it "should raise an exception if not syncable" do
      provider.not_syncable = true
      lambda{provider.sync_to_cache(userfile)}.should raise_error(CbrainError, "Error: provider #{provider.name} is not syncable.")
    end
    it "should raise an exception if sync_to_cache is called" do
      lambda{provider.sync_to_cache(userfile)}.should raise_error("Error: method not yet implemented in subclass.")
    end
  end
  
  describe "#sync_to_provider" do
    it "should raise an exception if not online" do
      provider.online = false
      lambda{provider.sync_to_provider(userfile)}.should raise_error(CbrainError, "Error: provider #{provider.name} is offline.")
    end
    it "should raise an exception if read only" do
      provider.read_only = true
      lambda{provider.sync_to_provider(userfile)}.should raise_error(CbrainError, "Error: provider #{provider.name} is read_only.")
    end
    it "should raise an exception if not syncable" do
      provider.not_syncable = true
      lambda{provider.sync_to_provider(userfile)}.should raise_error(CbrainError, "Error: provider #{provider.name} is not syncable.")
    end
    it "should raise an exception when sync_to_provider called but not implemented" do
      lambda{provider.sync_to_provider(userfile)}.should raise_error("Error: method not yet implemented in subclass.")
    end
  end
  
  describe "#cache_prepare" do
    it "should raise an exception if not online" do
      provider.online = false 
      lambda{provider.cache_prepare(userfile)}.should raise_error(CbrainError, "Error: provider #{provider.name} is offline.")
    end
    it "should raise an exception if read only" do
       provider.read_only = true
       lambda{provider.cache_prepare(userfile)}.should raise_error(CbrainError, "Error: provider #{provider.name} is read_only.")
    end
    it "should raise an exception if passed a string argument" do
      lambda{provider.cache_prepare("userfile")}.should raise_error(CbrainError, "DataProvider internal API change incompatibility (string vs userfile)")
    end
    describe "creating a cache subdirectory" do
      before(:each) do
        DataProvider.stub!(:cache_rootdir).and_return("cache")
        Dir.stub!(:mkdir)
      end
      it "should find the cache root" do
        DataProvider.should_receive(:cache_rootdir).and_return("cache")
        provider.cache_full_path(userfile).should be true
      end
      it "should create the subdirectory" do
        Dir.should_receive(:mkdir).at_least(:once)
        provider.cache_prepare(userfile).should be_true
      end
    end
  end
  
  describe "#cache_full_path" do
    it "should raise an exception if called with a string argument" do
      lambda{provider.cache_full_path("userfile")}.should raise_error(CbrainError, "DataProvider internal API change incompatibility (string vs userfile)")
    end
    describe "building a cache directory" do
      before(:each) do
        DataProvider.stub!(:cache_rootdir).and_return("cache")
        provider.stub!(:cache_subdirs_path).and_return("subdirs")
        userfile.stub!(:name).and_return("userfile")
      end
      it "should find the cache root" do
        DataProvider.should_receive(:cache_rootdir).and_return("cache")
        provider.cache_full_path(userfile).should be true
      end
      it "should determine the cache subdirectory" do
        provider.should_receive(:cache_subdirs_path).and_return("subdirs")
        provider.cache_full_path(userfile).should be true
      end
      it "should use the userfile name" do
        userfile.should_receive(:name).and_return("userfile")
        provider.cache_full_path(userfile).should be true
      end
    end
  end
  
  describe "#cache_readhandle" do
    before(:each) do
      provider.stub!(:sync_to_cache).and_return(true)
    end
    it "should raise an exception if offline" do
      provider.online = false
      lambda{provider.cache_readhandle(userfile)}.should raise_error(CbrainError, "Error: provider #{provider.name} is offline.")
    end
    it "should raise and exception if relative path argument set for a SingleFile" do
      userfile = Factory.build(:single_file)
      lambda{provider.cache_readhandle(userfile, "path")}.should raise_error(CbrainError, "Error: cannot use relative path argument with a SingleFile.")
    end
    it "should raise an exception if I try to read a non userfile" do 
      lambda{provider.cache_readhandle(userfile)}.should raise_error(CbrainError, "Error: read handle cannot be provided for non-file.")
    end
    describe "opening a readhandle" do
      before(:each) do
        provider.stub!(:cache_full_path).and_return("cache_path")
        File.stub!(:file?).and_return(true)
        File.stub!(:open)
      end
      it "should sync to cache" do
        provider.should_receive(:sync_to_cache)
        provider.cache_readhandle(userfile)
      end
      it "should determine the path in the cache" do
        provider.should_receive(:cache_full_path)
        provider.cache_readhandle(userfile)
      end
      it "should open a readhandle" do
        File.should_receive(:open).with(anything, "r")
        provider.cache_readhandle(userfile)
      end
    end
  end
  
  describe "#cache_writehandle" do
    it "should raise an exception when offline" do
      provider.online = false
      lambda{provider.cache_writehandle(userfile)}.should raise_error(CbrainError, "Error: provider #{provider.name} is offline.")
    end
    it "should raise an exception when read_only" do
      provider.read_only = true
      lambda{provider.cache_writehandle(userfile)}.should raise_error(CbrainError, "Error: provider #{provider.name} is read_only.")
    end
    it "should raise and exception if relative path argument set for a SingleFile" do
      userfile = Factory.build(:single_file)
      lambda{provider.cache_writehandle(userfile, "path")}.should raise_error(CbrainError, "Error: cannot use relative path argument with a SingleFile.")
    end
    describe "opening a writehandle" do
      before(:each) do
        provider.stub!(:cache_prepare)
        provider.stub!(:cache_full_path).and_return("cache_path")
        provider.stub!(:sync_to_provider)
        SyncStatus.stub!(:ready_to_modify_cache)
        File.stub!(:open)
      end
      it "should prepare the cache" do
        provider.should_receive(:cache_prepare)
        provider.cache_writehandle(userfile)
      end
      it "should determine the path in the cache" do
        provider.should_receive(:cache_full_path)
        provider.cache_writehandle(userfile)
      end
      it "should ensure that the cache is ready to be modified" do
        SyncStatus.should_receive(:ready_to_modify_cache)
        provider.cache_writehandle(userfile)
      end
      it "should open a writehandle" do
        SyncStatus.stub!(:ready_to_modify_cache).and_yield
        File.should_receive(:open).with(anything, "w")
        provider.cache_writehandle(userfile)
      end
      it "should sync the userfile back to the provider" do
        provider.should_receive(:sync_to_provider)
        provider.cache_writehandle(userfile)
      end
    end
  end
  
  describe "#cache_copy_from_local_file" do
    it "should raise an exception when offline" do
      provider.online = false
      lambda{provider.cache_copy_from_local_file(userfile, "localpath")}.should raise_error(CbrainError, "Error: provider #{provider.name} is offline.")
    end
    it "should raise an exception when read_only" do
      provider.read_only = true
      lambda{provider.cache_copy_from_local_file(userfile, "localpath")}.should raise_error(CbrainError, "Error: provider #{provider.name} is read_only.")
    end
    it "should raise an exception if userfile doesn't exist" do
      File.stub!(:exists?).and_return(false)
      lambda{provider.cache_copy_from_local_file(userfile, "localpath")}.should raise_error(CbrainError, /^Error: file does not exist/)
    end
    describe "checking file type conflicts" do
      before(:each) do
        File.stub!(:exists?).and_return(true)
        File.stub!(:directory?).and_return(false)
        File.stub!(:file?).and_return(false)
      end
      it "should raise an exception if directory given as local path for single file" do
        userfile = Factory.create(:single_file)
        File.stub!(:directory?).and_return(true)
        lambda{provider.cache_copy_from_local_file(userfile, "localpath")}.should raise_error(CbrainError, /^Error: incompatible directory .+ given for a SingleFile./)
      end
      it "should raise an exception if file given as local path for a file collection" do    
        userfile = Factory.create(:file_collection)
        File.stub!(:file?).and_return(true)
        lambda{provider.cache_copy_from_local_file(userfile, "localpath")}.should raise_error(CbrainError, /^Error: incompatible normal file .+ given for a FileCollection./)
      end
    end
    describe "copying from local file" do
      before(:each) do
        provider.stub!(:cache_prepare)
        provider.stub!(:cache_full_path).and_return("cache_path")
        provider.stub!(:sync_to_provider)
        provider.stub!(:bash_this)
        SyncStatus.stub!(:ready_to_modify_cache)
        FileUtils.stub!(:remove_entry)
        Dir.stub!(:mkdir)
        File.stub!(:file?).and_return(true)
        File.stub!(:directory?).and_return(false)
        File.stub!(:exists?).and_return(true)
      end
      it "should determine the path in the cache" do
        provider.should_receive(:cache_full_path)
        provider.cache_copy_from_local_file(userfile, "localpath")
      end
      it "should prepare the cache" do
        provider.should_receive(:cache_prepare)
        provider.cache_copy_from_local_file(userfile, "localpath")
      end
      it "should ensure that the cache is ready to be modified" do
        SyncStatus.should_receive(:ready_to_modify_cache)
        provider.cache_copy_from_local_file(userfile, "localpath")
      end
      it "should copy the file to the cache" do
        SyncStatus.stub!(:ready_to_modify_cache).and_yield
        provider.should_receive(:bash_this).with(/^rsync -a -l --delete/)
        provider.cache_copy_from_local_file(userfile, "localpath")
      end
      it "should raise an exception if the copy process fails" do
        SyncStatus.stub!(:ready_to_modify_cache).and_yield
        provider.stub!(:bash_this).and_return("error")
        lambda{provider.cache_copy_from_local_file(userfile, "localpath")}.should raise_error(CbrainError)
      end
      it "should sync the userfile to the provider" do
        provider.should_receive(:sync_to_provider)
        provider.cache_copy_from_local_file(userfile, "localpath")
      end
    end
  end
  describe "#cache_copy_to_local_file" do
    it "should raise an exception when offline" do
      provider.online = false
      lambda{provider.cache_copy_to_local_file(userfile, "localpath")}.should raise_error(CbrainError, "Error: provider #{provider.name} is offline.")
    end
    it "should raise an exception when read_only" do
      provider.read_only = true
      lambda{provider.cache_copy_to_local_file(userfile, "localpath")}.should raise_error(CbrainError, "Error: provider #{provider.name} is read_only.")
    end
    describe "copying to local file" do
      before(:each) do
        provider.stub!(:sync_to_cache)
        provider.stub!(:cache_prepare)
        provider.stub!(:cache_full_path).and_return("cache_path")
        provider.stub!(:bash_this)
        FileUtils.stub!(:remove_entry)
        Dir.stub!(:mkdir)
        File.stub!(:file?).and_return(true)
        File.stub!(:directory?).and_return(false)
        File.stub!(:exists?).and_return(true)
      end
      it "should sync the userfile to the cache" do
        provider.should_receive(:sync_to_cache)
        provider.cache_copy_to_local_file(userfile, "localpath")
      end
      it "should determine the path in the cache" do
        provider.should_receive(:cache_full_path)
        provider.cache_copy_to_local_file(userfile, "localpath")
      end
      it "should return true if the source and destination paths are the same" do
        provider.stub!(:cache_full_path).and_return("localpath")
        provider.cache_copy_to_local_file(userfile, "localpath").should be_true
      end
      it "should copy the file to the cache" do
        provider.should_receive(:bash_this).with(/^rsync -a -l --delete/)
        provider.cache_copy_to_local_file(userfile, "localpath")
      end
      it "should raise an exception if the copy process fails" do
        provider.stub!(:bash_this).and_return("error")
        lambda{provider.cache_copy_to_local_file(userfile, "localpath")}.should raise_error(CbrainError)
      end
    end
  end
  describe "#cache_erase" do
    before(:each) do
      provider.stub!(:cache_full_pathname).and_return(Pathname.new("cache_path"))
      SyncStatus.stub!(:ready_to_modify_cache).and_yield
      FileUtils.stub!(:remove_entry)
      Dir.stub!(:rmdir)
    end
    it "should ensure that the cache is ready to be modifiedand update the sync status" do
      SyncStatus.should_receive(:ready_to_modify_cache).with(anything, 'ProvNewer')
      provider.cache_erase(userfile)
    end
    it "should erase content from the cache" do
      FileUtils.should_receive(:remove_entry)
      Dir.should_receive(:rmdir)
      provider.cache_erase(userfile)
    end
  end
  describe "#cache_collection_index" do
    it "should raise an exception when offline" do
      provider.online = false
      lambda{provider.cache_collection_index(userfile)}.should raise_error(CbrainError, "Error: provider #{provider.name} is offline.")
    end
    it "should raise an exception if the userfile is not locally cached" do
      userfile.stub!(:is_locally_cached?).and_return(false)
      lambda{provider.cache_collection_index(userfile)}.should raise_error(CbrainError, "Error: userfile #{userfile.name} with ID #{userfile.id} is not cached.")
    end
    describe "producing a list of files" do
      let(:file_collection) {Factory.build(:file_collection)}
      let(:file_entry) do
        file_entry = double("file_entry").as_null_object
        file_entry.stub!(:name).and_return("file")
        file_entry.stub!(:ftype).and_return(:file)
        file_entry
      end
      
      before(:each) do
        provider.stub!(:cache_full_path).and_return(Pathname.new("cache_path"))
        userfile.stub!(:is_locally_cached?).and_return(true)
        file_collection.stub!(:is_locally_cached?).and_return(true)
        Dir.stub!(:chdir).and_yield
        Dir.stub!(:glob).and_return(["file1", "file2", "file3"])
        Dir.stub!(:entries).and_return(["file1", "file2", "file3"])
        File.stub!(:lstat).and_return(file_entry)
      end
      it "should get file information" do
        File.should_receive(:lstat).and_return(file_entry)
        provider.cache_collection_index(userfile)
      end
      it "should return one entry for a single file" do
        provider.cache_collection_index(userfile).should have(1).entry
      end
      it "should get full tree structure if :all given" do
        Dir.should_receive(:glob).and_return(["file1", "file2", "file3"])
        provider.cache_collection_index(file_collection)
      end
      it "should explore single level if :all not given" do
        Dir.should_receive(:entries).and_return(["file1", "file2", "file3"])
        provider.cache_collection_index(file_collection, "base")
      end
    end
  end
  describe "#provider_erase" do
    before(:each) do
      SyncStatus.stub!(:ready_to_modify_dp)
    end
    it "should raise an exception if offline" do
      provider.online = false
      lambda{provider.provider_erase(userfile)}.should raise_error(CbrainError, "Error: provider #{provider.name} is offline.")
    end
    it "should raise an exception if read only" do
      provider.read_only = true
      lambda{provider.provider_erase(userfile)}.should raise_error(CbrainError, "Error: provider #{provider.name} is read_only.")
    end
    it "should ensure that the data provider is ready to be modified" do
      SyncStatus.should_receive(:ready_to_modify_dp)
      provider.provider_erase(userfile)
    end
    it "should raise an exception, if not implemented in a subclass" do
      SyncStatus.stub!(:ready_to_modify_dp).and_yield
      lambda{provider.provider_erase(userfile)}.should raise_error("Error: method not yet implemented in subclass.")
    end
  end
  describe "#provider_rename"  do
    it "should raise an exception if offline" do
      provider.online = false
      lambda{provider.provider_rename(userfile, "abc")}.should raise_error(CbrainError, "Error: provider #{provider.name} is offline.")
    end
    it "should raise an exception if read only" do
      provider.read_only = true
      lambda{provider.provider_rename(userfile, "abc")}.should raise_error(CbrainError, "Error: provider #{provider.name} is read_only.")
    end
    it "should return true if old name and new name are the same" do
      provider.provider_rename(userfile, userfile.name).should be_true
    end
    it "should return false if new name is illegal" do
      provider.provider_rename(userfile, "&*!@^#%*").should be_false
    end
    it "should return false if the name is already used by another userfile" do
      conflict_file = Factory.create(:userfile, :name => "abc", :data_provider => provider)
      userfile.stub!(:user_id).and_return(conflict_file.user_id)
      provider.provider_rename(userfile, "abc").should be_false
    end
    describe "renaming on the provider" do
      before(:each) do
        provider.stub!(:cache_erase)
        provider.stub_chain(:userfiles, :first).and_return(nil)
        userfile.as_null_object
        SyncStatus.stub!(:ready_to_modify_dp)
      end
      it "should erase the file from the cache" do
        provider.should_receive(:cache_erase)
        provider.provider_rename(userfile, "abc")
      end
      it "should ensure that the data provider is ready to be modified" do
        SyncStatus.should_receive(:ready_to_modify_dp)
        provider.provider_rename(userfile, "abc")
      end
      it "should raise an exception, if not implemented in a subclass" do
        SyncStatus.stub!(:ready_to_modify_dp).and_yield
        lambda{provider.provider_rename(userfile, "abc")}.should raise_error("Error: method not yet implemented in subclass.")
      end
    end
  end
  describe "#provider_move_to_otherprovider" do
    let(:other_provider) { Factory.create(:data_provider, :online => true, :read_only => false) }
    before(:each) do
      userfile.as_null_object
    end
    it "should raise an exception if offline"do
      provider.online = false
      lambda{provider.provider_move_to_otherprovider(userfile, other_provider)}.should raise_error(CbrainError, "Error: provider #{provider.name} is offline.")
    end
    it "should raise an exception if read only" do
      provider.read_only = true
      lambda{provider.provider_rename(userfile, other_provider)}.should raise_error(CbrainError, "Error: provider #{provider.name} is read_only.")
    end
    it "should raise an exception if destination provider is offline" do
      other_provider.online = false
      lambda{provider.provider_move_to_otherprovider(userfile, other_provider)}.should raise_error(CbrainError, "Error: provider #{other_provider.name} is offline.")
    end
    it "should raise an exception if destination provider is read only" do
      other_provider.read_only = true
      lambda{provider.provider_move_to_otherprovider(userfile, other_provider)}.should raise_error(CbrainError, "Error: provider #{other_provider.name} is read_only.")
    end
    it "should return true if copying to itself" do
      provider.provider_move_to_otherprovider(userfile, provider).should be_true
    end
    it "should return false if new name is illegal" do
      provider.provider_move_to_otherprovider(userfile, other_provider, :name => "&*!@^#%*").should be_false
    end
    it "should return false if userfile not registered" do
      userfile.stub!(:id).and_return(nil)
      provider.provider_move_to_otherprovider(userfile, other_provider).should be_false
    end
    describe "moving the userfile" do
      before(:each) do
        provider.stub!(:sync_to_cache)
        provider.stub!(:provider_erase)
        other_provider.stub!(:cache_copy_from_local_file)
        SyncStatus.stub!(:ready_to_modify_cache)
      end
      describe "if a target file already exists" do
        let(:target_file) do
          tf = double("target_file")
          tf.stub!(:name).and_return("target_file")
          tf.stub!(:id).and_return(321)
          tf
        end
        before(:each) do
          Userfile.stub!(:find).and_return(target_file)
        end
        it "should return true if trying to move to same userfile" do
          Userfile.stub!(:find).and_return(userfile)
          provider.provider_move_to_otherprovider(userfile, other_provider).should be_true
        end
        it "should return false if target exists and crushing disallowed" do
          provider.provider_move_to_otherprovider(userfile, other_provider).should be_false
        end
        it "should return false if target exists, and source and target classes differ" do
          userfile.stub!(:class).and_return(SingleFile)
          target_file.stub!(:class).and_return(MincFile)
          provider.provider_move_to_otherprovider(userfile, other_provider, :crush_destination => true).should be_false
        end
        it "should destroy the target file, if crushing is allowed" do
          userfile.stub!(:class).and_return(MincFile)
          target_file.stub!(:class).and_return(MincFile)
          target_file.should_receive(:destroy)
          provider.provider_move_to_otherprovider(userfile, other_provider, :crush_destination => true)
        end
      end
      it "should sync the userfile to the cache" do
        provider.should_receive(:sync_to_cache)
        provider.provider_move_to_otherprovider(userfile, other_provider)
      end
      it "should erase from the provider" do
        provider.should_receive(:provider_erase)
        provider.provider_move_to_otherprovider(userfile, other_provider)
      end
      it "should update the userfile's logs" do
        userfile.should_receive(:addlog)
        provider.provider_move_to_otherprovider(userfile, other_provider)
      end
      it "should update the syncstatus" do
        SyncStatus.should_receive(:ready_to_modify_cache)
        provider.provider_move_to_otherprovider(userfile, other_provider)
      end
    end
  end
  describe "#provider_copy_to_otherprovider" do
    let(:other_provider) { Factory.create(:data_provider, :online => true, :read_only => false) }
    before(:each) do
      userfile.as_null_object
    end
    it "should raise an exception if offline" do
      provider.online = false
      lambda{provider.provider_copy_to_otherprovider(userfile, other_provider)}.should raise_error(CbrainError, "Error: provider #{provider.name} is offline.")
    end
    it "should raise an exception if destination provider is offline" do
      other_provider.online = false
      lambda{provider.provider_copy_to_otherprovider(userfile, other_provider)}.should raise_error(CbrainError, "Error: provider #{other_provider.name} is offline.")
    end
    it "should raise an exception if destination provider is read only" do
      other_provider.read_only = true
      lambda{provider.provider_copy_to_otherprovider(userfile, other_provider)}.should raise_error(CbrainError, "Error: provider #{other_provider.name} is read_only.")
    end
    it "should return false if new name is illegal" do
      provider.provider_copy_to_otherprovider(userfile, other_provider, :name => "&*!@^#%*").should be_false
    end
    it "should return false if userfile not registered" do
      userfile.stub!(:id).and_return(nil)
      provider.provider_copy_to_otherprovider(userfile, other_provider).should be_false
    end
    describe "copying the userfile" do
      before(:each) do
        provider.stub!(:sync_to_cache)
        provider.stub!(:provider_erase)
        other_provider.stub!(:cache_copy_from_local_file)
        SyncStatus.stub!(:ready_to_modify_cache)
      end
      describe "if a target file already exists" do
        let(:target_file) do
          tf = double("target_file")
          tf.stub!(:name).and_return("target_file")
          tf.stub!(:id).and_return(321)
          tf
        end
        before(:each) do
          Userfile.stub!(:find).and_return(target_file)
        end
        it "should return true if trying to move to same userfile" do
          Userfile.stub!(:find).and_return(userfile)
          provider.provider_copy_to_otherprovider(userfile, other_provider).should be_true
        end
        it "should return false if target exists and crushing disallowed" do
          provider.provider_copy_to_otherprovider(userfile, other_provider).should be_false
        end
        it "should return false if target exists, and source and target classes differ" do
          userfile.stub!(:class).and_return(SingleFile)
          target_file.stub!(:class).and_return(MincFile)
          provider.provider_copy_to_otherprovider(userfile, other_provider, :crush_destination => true).should be_false
        end
      end
      it "should sync the userfile to the cache" do
        provider.should_receive(:sync_to_cache)
        provider.provider_copy_to_otherprovider(userfile, other_provider)
      end
      it "should copy the file to the other provider" do
        other_provider.should_receive(:cache_copy_from_local_file)
        provider.provider_copy_to_otherprovider(userfile, other_provider)
      end
      it "should update the logs on both files" do
        userfile.should_receive(:addlog).at_least(:once)
        provider.provider_copy_to_otherprovider(userfile, other_provider)
      end
    end
  end
  
  describe "#provider_list_all" do
    it "should raise an exception if offline" do
      provider.online = false
      lambda{provider.provider_list_all}.should raise_error(CbrainError, "Error: provider #{provider.name} is offline.")
    end
    it "should raise an exception if not browsable" do
      lambda{provider.provider_list_all}.should raise_error(CbrainError, "Error: provider #{provider.name} is not browsable.")
    end
    it "should raise an exception, if not implemented in a subclass" do
      provider.stub!(:is_browsable?).and_return(true)
      lambda{provider.provider_list_all}.should raise_error("Error: method not yet implemented in subclass.")
    end
  end
  describe "#provider_collection_index" do
    it "should raise an exception if offline" do
      provider.online = false
      lambda{provider.provider_collection_index(userfile)}.should raise_error(CbrainError, "Error: provider #{provider.name} is offline.")
    end
    it "should raise an exception, if not implemented in a subclass" do
      lambda{provider.provider_collection_index(userfile)}.should raise_error("Error: method not yet implemented in subclass.")
    end
  end
  describe "#provider_readhandle" do
    it "should raise an exception if offline" do
      provider.online = false
      lambda{provider.provider_readhandle(userfile)}.should raise_error(CbrainError, "Error: provider #{provider.name} is offline.")
    end
    it "should read from the cache if userfile is locally synced" do
      userfile.stub!(:is_locally_synced?).and_return(true)
      provider.should_receive(:cache_readhandle)
      provider.provider_readhandle(userfile)
    end
    it "should raise an exception if not implemented in a subclass, and userfile not locally synced" do
      userfile.stub!(:is_locally_synced?).and_return(false)
      lambda{provider.provider_readhandle(userfile)}.should raise_error("Error: method not yet implemented in subclass.")
    end
  end
  describe "#provider_full_path" do
    it "should raise an exception, if not implemented in a subclass" do
      lambda{provider.provider_full_path(userfile)}.should raise_error("Error: method not yet implemented in subclass.")
    end
  end
  describe "#site" do
    it "should return the associated site" do
      provider.site.should == provider.user.site
    end
  end
  
end
