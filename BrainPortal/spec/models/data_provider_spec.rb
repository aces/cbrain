
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

describe DataProvider do

  let(:provider)        { create(:data_provider, :online => true, :read_only => false) }
  let(:userfile)        { mock_model(Userfile, :name => "userfile_mock", :user_id => 1).as_null_object }
  let(:singlefile)      { mock_model(SingleFile, :name => "singlefile_mock", :user_id => 1).as_null_object }
  let(:filecollection)  { mock_model(FileCollection, :name => "filecollection_mock", :user_id => 1).as_null_object }

  describe "validations" do
    it "should create a new instance given valid attributes" do
      expect(provider.valid?).to be(true)
    end

    it "should not save with a blank name" do
      provider.name = nil
      expect(provider.valid?).to be(false)
    end

    it "should not save with no owner" do
      provider.user = nil
      expect(provider.valid?).to be(false)
    end

    it "should not save with no group" do
      provider.group =nil
      expect(provider.valid?).to be(false)
    end

    it "should not accept a dp without a value for read_only" do
      provider.read_only = nil
      expect(provider.valid?).to be(false)
    end

    it "should accept read_only being false" do
      provider.read_only = false
      expect(provider.valid?).to be true
    end

    it "should accept read_only being true" do
      provider.read_only = true
      expect(provider.valid?).to be true
    end

    it "should not accept a name with invalid chars" do
      provider.name = "*@$%"
      expect(provider.valid?).to be(false)
    end

    it "should not accept a remote_host with invalid chars" do
      provider.remote_host = "*@$%"
      expect(provider.valid?).to be(false)
    end


    it "should not accept a remote_user with invalid chars" do
      provider.remote_user = "*@$%"
      expect(provider.valid?).to be(false)
    end


    it "should not have a remote_dir path with invalid characters" do
      provider.remote_dir = "*?$@"
      expect(provider.valid?).to be(false)
    end
  end

  describe DataProvider::FileInfo do
    let(:file_info) {DataProvider::FileInfo.new}

    describe "#depth" do
      it "should calculate the depth of the userfile" do
        file_info.name = "/x/y/z"
        expect(file_info.depth).to eq(3)
      end
      it "should raise an exception if no name is given" do
        file_info.name = ""
        expect{file_info.depth}.to raise_error(CbrainError, "File doesn't have a name.")
      end
    end
  end

  describe "#is_alive?" do
     it "should return false when is_alive? is called on offline provider" do
       provider.online = false
       expect(provider.is_alive?).to be(false)
    end

    it "should raise an exception if called but not implemented in a subclass" do
      expect{provider.is_alive?}.to raise_error("Error: method not yet implemented in subclass.")
    end

    it "should return false if impl_is_alive? returns false" do
      allow(provider).to receive(:impl_is_alive?).and_return(false)
      provider.online = true
      expect(provider.is_alive?).to be(false)
    end

    it "should raise and exception when is_alive! is called with an offline provider" do
      provider.online = false
      expect{provider.is_alive!}.to raise_error(CbrainError, "Error: provider #{provider.name} is not accessible right now.")
    end
  end

  describe "#is_browsable" do
    specify { expect(provider.is_browsable?).to be_falsey}
  end

  describe "#is_fast_syncing?" do
    specify { expect(provider.is_fast_syncing?).to be_falsey}
  end

  describe "#allow_file_owner_change?" do
    specify { expect(provider.allow_file_owner_change?).to be_falsey}
  end

  describe "#sync_to_cache" do
    it "should raise an exception if not online" do
      provider.online = false
      expect{provider.sync_to_cache(userfile)}.to raise_error(CbrainError, "Error: provider #{provider.name} is offline.")
    end
    it "should raise an exception if not syncable" do
      provider.not_syncable = true
      expect{provider.sync_to_cache(userfile)}.to raise_error(CbrainError, "Error: provider #{provider.name} is not syncable.")
    end
    it "should raise an exception if sync_to_cache is called" do
      expect{provider.sync_to_cache(userfile)}.to raise_error("Error: method not yet implemented in subclass.")
    end
  end

  describe "#sync_to_provider" do
    before(:each) do
      allow(userfile).to receive(:immutable?).and_return(false)
    end
    it "should raise an exception if not online" do
      provider.online = false
      expect{provider.sync_to_provider(userfile)}.to raise_error(CbrainError, "Error: provider #{provider.name} is offline.")
    end
    it "should raise an exception if read only" do
      provider.read_only = true
      expect{provider.sync_to_provider(userfile)}.to raise_error(CbrainError, "Error: provider #{provider.name} is read_only.")
    end
    it "should raise an exception if not syncable" do
      provider.not_syncable = true
      expect{provider.sync_to_provider(userfile)}.to raise_error(CbrainError, "Error: provider #{provider.name} is not syncable.")
    end
    it "should raise an exception when sync_to_provider called but not implemented" do
      expect{provider.sync_to_provider(userfile)}.to raise_error("Error: method not yet implemented in subclass.")
    end
    it "should raise an exception if userfile is immutable" do
      allow(userfile).to receive(:immutable?).and_return(true)
      expect{provider.sync_to_provider(userfile)}.to raise_error(CbrainError, /immutable/)
    end
  end

  describe "#cache_prepare" do
    it "should raise an exception if not online" do
      provider.online = false
      expect{provider.cache_prepare(userfile)}.to raise_error(CbrainError, "Error: provider #{provider.name} is offline.")
    end
    it "should raise an exception if read only" do
       provider.read_only = true
       expect{provider.cache_prepare(userfile)}.to raise_error(CbrainError, "Error: provider #{provider.name} is read_only.")
    end
    context "creating a cache subdirectory" do
      before(:each) do
        allow(SyncStatus).to receive(:ready_to_modify_cache).and_yield
        allow(DataProvider).to receive(:cache_rootdir).and_return("cache")
        allow(File).to receive(:directory?).and_return(false)
        allow(Dir).to receive(:mkdir)
      end
      it "should ensure that the cache is ready to be modified" do
        expect(SyncStatus).to receive(:ready_to_modify_cache)
        expect(provider.cache_prepare(userfile)).to be_truthy
      end
      it "should raise an exception if passed a string argument" do
        expect{provider.cache_prepare("userfile")}.to raise_error
      end
      it "should create the subdirectory if it does not exist" do
        expect(Dir).to receive(:mkdir).at_least(:once)
        expect(provider.cache_prepare(userfile)).to be_truthy
      end
      it "should not attempt to create the subdirectory if it already exists" do
        allow(File).to receive(:directory?).and_return(true)
        expect(Dir).not_to receive(:mkdir)
        expect(provider.cache_prepare(userfile)).to be_truthy
      end
    end
  end

  describe "#cache_full_path" do
    it "should raise an exception if called with a string argument" do
      expect{provider.cache_full_path("userfile")}.to raise_error
    end
    context "building a cache directory" do
      before(:each) do
        allow(DataProvider).to receive(:cache_rootdir).and_return("cache")
        allow(provider).to receive(:cache_subdirs_path).and_return("subdirs")
        allow(userfile).to receive(:name).and_return("userfile")
      end
      it "should find the cache root" do
        expect(DataProvider).to receive(:cache_rootdir).and_return("cache")
        expect(provider.cache_full_path(userfile)).to be_truthy
      end
      it "should determine the cache subdirectory" do
        expect(provider).to receive(:cache_subdirs_path).and_return("subdirs")
        expect(provider.cache_full_path(userfile)).to be_truthy
      end
      it "should use the userfile name" do
        expect(userfile).to receive(:name).and_return("userfile")
        expect(provider.cache_full_path(userfile)).to be_truthy
      end
    end
  end

  describe "#cache_readhandle" do
    before(:each) do
      allow(userfile).to receive(:immutable?).and_return(false)
      allow(provider).to receive(:sync_to_cache).and_return(true)
    end
    it "should raise an exception if offline" do
      provider.online = false
      expect{provider.cache_readhandle(userfile)}.to raise_error(CbrainError, "Error: provider #{provider.name} is offline.")
    end
    it "should raise and exception if relative path argument set for a SingleFile" do
      expect{provider.cache_readhandle(singlefile, "path")}.to raise_error(CbrainError, "Error: cannot use relative path argument with a SingleFile.")
    end
    context "opening a readhandle" do
      before(:each) do
        allow(provider).to receive(:cache_full_path).and_return("cache_path")
        allow(File).to receive(:file?).and_return(true)
        allow(File).to receive(:open)
      end
      it "should raise an exception if I try to read a non userfile" do
        allow(File).to receive(:file?).and_return(false)
        expect{provider.cache_readhandle(userfile)}.to raise_error(CbrainError, "Error: read handle cannot be provided for non-file.")
      end
      it "should sync to cache" do
        expect(provider).to receive(:sync_to_cache)
        provider.cache_readhandle(userfile)
      end
      it "should determine the path in the cache" do
        expect(provider).to receive(:cache_full_path)
        provider.cache_readhandle(userfile)
      end
      it "should open a readhandle" do
        expect(File).to receive(:open).with(anything, "r")
        provider.cache_readhandle(userfile)
      end
    end
  end

  describe "#cache_writehandle" do
    it "should raise an exception when offline" do
      provider.online = false
      expect{provider.cache_writehandle(userfile)}.to raise_error(CbrainError, "Error: provider #{provider.name} is offline.")
    end
    it "should raise an exception when read_only" do
      provider.read_only = true
      expect{provider.cache_writehandle(userfile)}.to raise_error(CbrainError, "Error: provider #{provider.name} is read_only.")
    end
    it "should raise and exception if relative path argument set for a SingleFile" do
      allow(singlefile).to receive(:immutable?).and_return(false)
      expect{provider.cache_writehandle(singlefile, "path")}.to raise_error(CbrainError, "Error: cannot use relative path argument with a SingleFile.")
    end
    it "should raise an exception if userfile is immutable" do
      allow(userfile).to receive(:immutable?).and_return(true)
      expect{provider.sync_to_provider(userfile)}.to raise_error(CbrainError, /immutable/)
    end
    context "opening a writehandle" do
      before(:each) do
        allow(provider).to receive(:cache_prepare)
        allow(provider).to receive(:cache_full_path).and_return("cache_path")
        allow(provider).to receive(:sync_to_provider)
        allow(userfile).to receive(:immutable?).and_return(false)
        allow(SyncStatus).to receive(:ready_to_modify_cache)
        allow(File).to receive(:open)
      end
      it "should prepare the cache" do
        expect(provider).to receive(:cache_prepare)
        provider.cache_writehandle(userfile)
      end
      it "should determine the path in the cache" do
        expect(provider).to receive(:cache_full_path)
        provider.cache_writehandle(userfile)
      end
      it "should ensure that the cache is ready to be modified" do
        expect(SyncStatus).to receive(:ready_to_modify_cache)
        provider.cache_writehandle(userfile)
      end
      it "should open a writehandle" do
        allow(SyncStatus).to receive(:ready_to_modify_cache).and_yield
        expect(File).to receive(:open).with(anything, "w:BINARY")
        provider.cache_writehandle(userfile)
      end
      it "should sync the userfile back to the provider" do
        expect(provider).to receive(:sync_to_provider)
        provider.cache_writehandle(userfile)
      end
    end
  end

  describe "#cache_copy_from_local_file" do
    before(:each) do
      allow(userfile).to receive(:immutable?).and_return(false)
      allow(DataProvider).to receive(:cache_rootdir).and_return("cache")
    end

    it "should raise an exception when offline" do
      provider.online = false
      expect{provider.cache_copy_from_local_file(userfile, "localpath")}.to raise_error(CbrainError, "Error: provider #{provider.name} is offline.")
    end
    it "should raise an exception when read_only" do
      provider.read_only = true
      expect{provider.cache_copy_from_local_file(userfile, "localpath")}.to raise_error(CbrainError, "Error: provider #{provider.name} is read_only.")
    end
    it "should raise an exception if userfile doesn't exist" do
      allow(File).to receive(:exists?).and_return(false)
      expect{provider.cache_copy_from_local_file(userfile, "localpath")}.to raise_error(CbrainError, /^Error: file does not exist/)
    end
    it "should raise an exception if userfile is immutable" do
      allow(userfile).to receive(:immutable?).and_return(true)
      expect{provider.sync_to_provider(userfile)}.to raise_error(CbrainError, /immutable/)
    end
    context "checking file type conflicts" do
      before(:each) do
        allow(File).to receive(:exists?).and_return(true)
        allow(File).to receive(:directory?).and_return(false)
        allow(File).to receive(:file?).and_return(false)
      end
      it "should raise an exception if directory given as local path for single file" do
        allow(File).to receive(:directory?).and_return(true)
        allow(singlefile).to receive(:immutable?).and_return(false)
        expect{provider.cache_copy_from_local_file(singlefile, "localpath")}.to raise_error(CbrainError, /^Error: incompatible directory .+ given for a SingleFile./)
      end
      it "should raise an exception if file given as local path for a file collection" do
        allow(File).to receive(:file?).and_return(true)
        allow(filecollection).to receive(:immutable?).and_return(false)
        expect{provider.cache_copy_from_local_file(filecollection, "localpath")}.to raise_error(CbrainError, /^Error: incompatible normal file .+ given for a FileCollection./)
      end
    end
    context "copying from local file" do
      before(:each) do
        allow(provider).to   receive(:cache_prepare)
        allow(provider).to   receive(:cache_full_path).and_return("cache_path")
        allow(provider).to   receive(:sync_to_provider)
        allow(provider).to   receive(:bash_this)
        allow(SyncStatus).to receive(:ready_to_modify_cache)
        allow(FileUtils).to  receive(:remove_entry)
        allow(Dir).to        receive(:mkdir)
        allow(File).to       receive(:file?).and_return(true)
        allow(File).to       receive(:directory?).and_return(false)
        allow(File).to       receive(:exists?).and_return(true)
      end
      it "should determine the path in the cache" do
        expect(provider).to receive(:cache_full_path)
        provider.cache_copy_from_local_file(userfile, "localpath")
      end
      it "should prepare the cache" do
        expect(provider).to receive(:cache_prepare)
        provider.cache_copy_from_local_file(userfile, "localpath")
      end
      it "should ensure that the cache is ready to be modified" do
        expect(SyncStatus).to receive(:ready_to_modify_cache)
        provider.cache_copy_from_local_file(userfile, "localpath")
      end
      it "should copy the file to the cache" do
        allow(SyncStatus).to receive(:ready_to_modify_cache).and_yield
        expect(provider).to receive(:bash_this).with(/^rsync -a -l --delete/)
        provider.cache_copy_from_local_file(userfile, "localpath")
      end
      it "should raise an exception if the copy process fails" do
        allow(SyncStatus).to receive(:ready_to_modify_cache).and_yield
        allow(provider).to receive(:bash_this).and_return("error")
        expect{provider.cache_copy_from_local_file(userfile, "localpath")}.to raise_error(CbrainError)
      end
      it "should sync the userfile to the provider" do
        expect(provider).to receive(:sync_to_provider)
        provider.cache_copy_from_local_file(userfile, "localpath")
      end
    end
  end

  describe "#cache_copy_to_local_file" do
    it "should raise an exception when offline" do
      provider.online = false
      expect{provider.cache_copy_to_local_file(userfile, "localpath")}.to raise_error(CbrainError, "Error: provider #{provider.name} is offline.")
    end
    it "should raise an exception when read_only" do
      provider.read_only = true
      expect{provider.cache_copy_to_local_file(userfile, "localpath")}.to raise_error(CbrainError, "Error: provider #{provider.name} is read_only.")
    end
    context "copying to local file" do
      before(:each) do
        allow(provider).to receive(:sync_to_cache)
        allow(provider).to receive(:cache_prepare)
        allow(provider).to receive(:cache_full_path).and_return("cache_path")
        allow(provider).to receive(:bash_this)
        allow(FileUtils).to receive(:remove_entry)
        allow(Dir).to receive(:mkdir)
        allow(File).to receive(:file?).and_return(true)
        allow(File).to receive(:directory?).and_return(false)
        allow(File).to receive(:exists?).and_return(true)
      end
      it "should sync the userfile to the cache" do
        expect(provider).to receive(:sync_to_cache)
        provider.cache_copy_to_local_file(userfile, "localpath")
      end
      it "should determine the path in the cache" do
        expect(provider).to receive(:cache_full_path)
        provider.cache_copy_to_local_file(userfile, "localpath")
      end
      it "should return true if the source and destination paths are the same" do
        allow(provider).to receive(:cache_full_path).and_return("localpath")
        expect(provider.cache_copy_to_local_file(userfile, "localpath")).to be_truthy
      end
      it "should copy the file to the cache" do
        expect(provider).to receive(:bash_this).with(/^rsync -a -l --delete/)
        provider.cache_copy_to_local_file(userfile, "localpath")
      end
      it "should raise an exception if the copy process fails" do
        allow(provider).to receive(:bash_this).and_return("error")
        expect{provider.cache_copy_to_local_file(userfile, "localpath")}.to raise_error(CbrainError)
      end
    end
  end

  describe "#cache_erase" do
    before(:each) do
      allow(DataProvider).to receive(:cache_rootdir).and_return("cache")
      allow(provider).to receive(:cache_full_pathname).and_return(Pathname.new("cache_path"))
      allow(SyncStatus).to receive(:ready_to_modify_cache).and_yield
      allow(FileUtils).to receive(:remove_entry)
      allow(Dir).to receive(:rmdir)
    end
    it "should ensure that the cache is ready to be modified and update the sync status" do
      expect(SyncStatus).to receive(:ready_to_modify_cache)
      provider.cache_erase(userfile)
    end
    it "should erase content from the cache" do
      expect(FileUtils).to receive(:remove_entry)
      expect(Dir).to receive(:rmdir)
      provider.cache_erase(userfile)
    end
  end

  describe "#cache_collection_index" do
    it "should raise an exception when offline" do
      provider.online = false
      expect{provider.cache_collection_index(userfile)}.to raise_error(CbrainError, "Error: provider #{provider.name} is offline.")
    end
    it "should raise an exception if the userfile is not locally cached" do
      allow(userfile).to receive(:is_locally_cached?).and_return(false)
      expect{provider.cache_collection_index(userfile)}.to raise_error(CbrainError, "Error: userfile #{userfile.name} with ID #{userfile.id} is not cached.")
    end
    context "producing a list of files" do
      let(:file_collection) {build(:file_collection)}
      let(:file_entry) {double("file_entry", :name => "file", :ftype => :file).as_null_object}

      before(:each) do
        allow(provider).to receive(:cache_full_path).and_return(Pathname.new("cache_path"))
        allow(userfile).to receive(:is_locally_cached?).and_return(true)
        allow(file_collection).to receive(:is_locally_cached?).and_return(true)
        allow(Dir).to receive(:chdir).and_yield
        allow(Dir).to receive(:glob).and_return(["file1", "file2", "file3"])
        allow(Dir).to receive(:entries).and_return(["file1", "file2", "file3"])
        allow(File).to receive(:lstat).and_return(file_entry)
      end
      it "should get file information" do
        expect(File).to receive(:lstat).and_return(file_entry)
        provider.cache_collection_index(userfile)
      end
      it "should return one entry for a single file" do
        expect(provider.cache_collection_index(userfile).size).to eq(1)
      end
      it "should get full tree structure if :all given" do
        expect(Dir).to receive(:glob).and_return(["file1", "file2", "file3"])
        provider.cache_collection_index(file_collection)
      end
      it "should explore single level if :all not given" do
        expect(Dir).to receive(:entries).and_return(["file1", "file2", "file3"])
        provider.cache_collection_index(file_collection, "base")
      end
    end
  end

  describe "#provider_erase" do
    before(:each) do
      allow(userfile).to receive(:immutable?).and_return(false)
      allow(SyncStatus).to receive(:ready_to_modify_dp)
    end
    it "should raise an exception if offline" do
      provider.online = false
      expect{provider.provider_erase(userfile)}.to raise_error(CbrainError, "Error: provider #{provider.name} is offline.")
    end
    it "should raise an exception if read only" do
      provider.read_only = true
      expect{provider.provider_erase(userfile)}.to raise_error(CbrainError, "Error: provider #{provider.name} is read_only.")
    end
    it "should ensure that the data provider is ready to be modified" do
      expect(SyncStatus).to receive(:ready_to_modify_dp)
      provider.provider_erase(userfile)
    end
    it "should raise an exception if userfile is immutable" do
      allow(userfile).to receive(:immutable?).and_return(true)
      expect{provider.sync_to_provider(userfile)}.to raise_error(CbrainError, /immutable/)
    end
    it "should raise an exception, if not implemented in a subclass" do
      allow(SyncStatus).to receive(:ready_to_modify_dp).and_yield
      expect{provider.provider_erase(userfile)}.to raise_error("Error: method not yet implemented in subclass.")
    end
  end

  describe "#provider_rename"  do
    before(:each) do
      allow(userfile).to receive(:immutable?).and_return(false)
    end
    it "should raise an exception if offline" do
      provider.online = false
      expect{provider.provider_rename(userfile, "abc")}.to raise_error(CbrainError, "Error: provider #{provider.name} is offline.")
    end
    it "should raise an exception if read only" do
      provider.read_only = true
      expect{provider.provider_rename(userfile, "abc")}.to raise_error(CbrainError, "Error: provider #{provider.name} is read_only.")
    end
    it "should return true if old name and new name are the same" do
      expect(provider.provider_rename(userfile, userfile.name)).to be_truthy
    end
    it "should return false if new name is illegal" do
      expect(provider.provider_rename(userfile, "&*!@^#%*")).to be_falsey
    end
    it "should return false if the name is already used by another userfile" do
      conflict_file = create(:userfile, :name => "abc", :data_provider => provider)
      allow(userfile).to receive(:user_id).and_return(conflict_file.user_id)
      expect(provider.provider_rename(userfile, "abc")).to be_falsey
    end
    it "should raise an exception if userfile is immutable" do
      allow(userfile).to receive(:immutable?).and_return(true)
      expect{provider.sync_to_provider(userfile)}.to raise_error(CbrainError, /immutable/)
    end
    context "renaming on the provider" do
      before(:each) do
        allow(provider).to receive(:cache_erase)
        allow(provider).to receive_message_chain(:userfiles, :first).and_return(nil)
        userfile.as_null_object
        allow(SyncStatus).to receive(:ready_to_modify_dp)
      end
      it "should erase the file from the cache" do
        expect(provider).to receive(:cache_erase)
        provider.provider_rename(userfile, "abc")
      end
      it "should ensure that the data provider is ready to be modified" do
        expect(SyncStatus).to receive(:ready_to_modify_dp)
        provider.provider_rename(userfile, "abc")
      end
      it "should raise an exception, if not implemented in a subclass" do
        allow(SyncStatus).to receive(:ready_to_modify_dp).and_yield
        expect{provider.provider_rename(userfile, "abc")}.to raise_error("Error: method not yet implemented in subclass.")
      end
    end
  end

  describe "#provider_move_to_otherprovider" do
    let(:other_provider) { create(:data_provider, :online => true, :read_only => false) }
    before(:each) do
      allow(userfile).to receive(:transaction).and_yield
      allow(userfile).to receive(:immutable?).and_return(false)
    end
    it "should raise an exception if offline"do
      provider.online = false
      expect{provider.provider_move_to_otherprovider(userfile, other_provider)}.to raise_error(CbrainError, "Error: provider #{provider.name} is offline.")
    end
    it "should raise an exception if read only" do
      provider.read_only = true
      expect{provider.provider_rename(userfile, other_provider)}.to raise_error(CbrainError, "Error: provider #{provider.name} is read_only.")
    end
    it "should raise an exception if destination provider is offline" do
      other_provider.online = false
      expect{provider.provider_move_to_otherprovider(userfile, other_provider)}.to raise_error(CbrainError, "Error: provider #{other_provider.name} is offline.")
    end
    it "should raise an exception if destination provider is read only" do
      other_provider.read_only = true
      expect{provider.provider_move_to_otherprovider(userfile, other_provider)}.to raise_error(CbrainError, "Error: provider #{other_provider.name} is read_only.")
    end
    it "should raise an exception if userfile is immutable" do
      allow(userfile).to receive(:immutable?).and_return(true)
      expect{provider.sync_to_provider(userfile)}.to raise_error(CbrainError, /immutable/)
    end
    it "should return true if copying to itself" do
      expect(provider.provider_move_to_otherprovider(userfile, provider)).to be_truthy
    end
    it "should return false if new name is illegal" do
      expect(provider.provider_move_to_otherprovider(userfile, other_provider, :name => "&*!@^#%*")).to be_falsey
    end
    it "should return false if userfile not registered" do
      allow(userfile).to receive(:id).and_return(nil)
      expect(provider.provider_move_to_otherprovider(userfile, other_provider)).to be_falsey
    end
    context "moving the userfile" do
      before(:each) do
        allow(provider).to receive(:sync_to_cache)
        allow(provider).to receive(:provider_erase)
        allow(other_provider).to receive(:cache_copy_from_local_file)
        allow(SyncStatus).to receive(:ready_to_modify_cache)
      end
      describe "if a target file already exists" do
        let(:target_file) { double("target_file", :name => "target_file", :id => 321) }

        before(:each) do
          allow(Userfile).to receive_message_chain(:where, :first).and_return(target_file)
        end
        it "should return true if trying to move to same userfile" do
          allow(Userfile).to receive_message_chain(:where, :first).and_return(userfile)
          expect(provider.provider_move_to_otherprovider(userfile, other_provider)).to be_truthy
        end
        it "should return false if target exists and crushing disallowed" do
          expect(provider.provider_move_to_otherprovider(userfile, other_provider)).to be_falsey
        end
        it "should return false if target exists, and source and target classes differ" do
          allow(userfile).to receive(:class).and_return(SingleFile)
          allow(target_file).to receive(:class).and_return(TextFile)
          expect(provider.provider_move_to_otherprovider(userfile, other_provider, :crush_destination => true)).to be_falsey
        end
        it "should destroy the target file, if crushing is allowed" do
          allow(userfile).to receive(:class).and_return(TextFile)
          allow(target_file).to receive(:class).and_return(TextFile)
          expect(target_file).to receive(:destroy)
          provider.provider_move_to_otherprovider(userfile, other_provider, :crush_destination => true)
        end
      end
      it "should sync the userfile to the cache" do
        expect(provider).to receive(:sync_to_cache)
        provider.provider_move_to_otherprovider(userfile, other_provider)
      end
      it "should erase from the provider" do
        expect(provider).to receive(:provider_erase)
        provider.provider_move_to_otherprovider(userfile, other_provider)
      end
      it "should update the userfile's logs" do
        expect(userfile).to receive(:addlog)
        provider.provider_move_to_otherprovider(userfile, other_provider)
      end
      it "should update the syncstatus" do
        expect(SyncStatus).to receive(:ready_to_modify_cache)
        provider.provider_move_to_otherprovider(userfile, other_provider)
      end
    end
  end

  describe "#provider_copy_to_otherprovider" do
    let(:other_provider) { create(:data_provider, :online => true, :read_only => false) }
    before(:each) do
      allow(userfile).to receive(:transaction).and_yield
    end
    it "should raise an exception if offline" do
      provider.online = false
      expect{provider.provider_copy_to_otherprovider(userfile, other_provider)}.to raise_error(CbrainError, "Error: provider #{provider.name} is offline.")
    end
    it "should raise an exception if destination provider is offline" do
      other_provider.online = false
      expect{provider.provider_copy_to_otherprovider(userfile, other_provider)}.to raise_error(CbrainError, "Error: provider #{other_provider.name} is offline.")
    end
    it "should raise an exception if destination provider is read only" do
      other_provider.read_only = true
      expect{provider.provider_copy_to_otherprovider(userfile, other_provider)}.to raise_error(CbrainError, "Error: provider #{other_provider.name} is read_only.")
    end
    it "should return false if new name is illegal" do
      expect(provider.provider_copy_to_otherprovider(userfile, other_provider, :name => "&*!@^#%*")).to be_falsey
    end
    it "should return false if userfile not registered" do
      allow(userfile).to receive(:id).and_return(nil)
      expect(provider.provider_copy_to_otherprovider(userfile, other_provider)).to be_falsey
    end
    context "copying the userfile" do
      before(:each) do
        allow(provider).to receive(:sync_to_cache)
        allow(provider).to receive(:provider_erase)
        allow(other_provider).to receive(:cache_copy_from_local_file)
        allow(SyncStatus).to receive(:ready_to_modify_cache)
      end
      describe "if a target file already exists" do
        let(:target_file) { double("target_file", :name => "target_file", :id => 321) }

        before(:each) do
          allow(Userfile).to receive_message_chain(:where, :first).and_return(target_file)
        end
        it "should return true if trying to move to same userfile" do
          allow(Userfile).to receive_message_chain(:where, :first).and_return(userfile)
          expect(provider.provider_copy_to_otherprovider(userfile, other_provider)).to be_truthy
        end
        it "should return false if target exists and crushing disallowed" do
          expect(provider.provider_copy_to_otherprovider(userfile, other_provider)).to be_falsey
        end
        it "should return false if target exists, and source and target classes differ" do
          allow(userfile).to receive(:class).and_return(SingleFile)
          allow(target_file).to receive(:class).and_return(TextFile)
          expect(provider.provider_copy_to_otherprovider(userfile, other_provider, :crush_destination => true)).to be_falsey
        end
      end
      it "should sync the userfile to the cache" do
        expect(provider).to receive(:sync_to_cache)
        provider.provider_copy_to_otherprovider(userfile, other_provider)
      end
      it "should copy the file to the other provider" do
        expect(other_provider).to receive(:cache_copy_from_local_file)
        provider.provider_copy_to_otherprovider(userfile, other_provider)
      end
      it "should update the logs on both files" do
        expect(userfile).to receive(:addlog).at_least(:once)
        provider.provider_copy_to_otherprovider(userfile, other_provider)
      end
    end
  end

  describe "#provider_list_all" do
    it "should raise an exception if offline" do
      provider.online = false
      expect{provider.provider_list_all}.to raise_error(CbrainError, "Error: provider #{provider.name} is offline.")
    end
    it "should raise an exception if not browsable" do
      expect{provider.provider_list_all}.to raise_error(CbrainError, "Error: provider #{provider.name} is not browsable.")
    end
    it "should raise an exception, if not implemented in a subclass" do
      allow(provider).to receive(:is_browsable?).and_return(true)
      expect{provider.provider_list_all}.to raise_error("Error: method not yet implemented in subclass.")
    end
  end

  describe "#provider_collection_index" do
    it "should raise an exception if offline" do
      provider.online = false
      expect{provider.provider_collection_index(userfile)}.to raise_error(CbrainError, "Error: provider #{provider.name} is offline.")
    end
    it "should raise an exception, if not implemented in a subclass" do
      expect{provider.provider_collection_index(userfile)}.to raise_error("Error: method not yet implemented in subclass.")
    end
  end

  describe "#provider_readhandle" do
    it "should raise an exception if offline" do
      provider.online = false
      expect{provider.provider_readhandle(userfile)}.to raise_error(CbrainError, "Error: provider #{provider.name} is offline.")
    end
    it "should read from the cache if userfile is locally synced" do
      allow(userfile).to receive(:is_locally_synced?).and_return(true)
      expect(provider).to receive(:cache_readhandle)
      provider.provider_readhandle(userfile)
    end
    it "should raise an exception if not implemented in a subclass, and userfile not locally synced" do
      allow(userfile).to receive(:is_locally_synced?).and_return(false)
      expect{provider.provider_readhandle(userfile)}.to raise_error("Error: method not yet implemented in subclass.")
    end
  end

  describe "#site" do
    it "should return the associated site" do
      expect(provider.site).to eq(provider.user.site)
    end
  end

  describe "#validate_destroy" do
    it "should prevent desctruction if associated userfiles still exist" do
      destroyed_provider = create(:data_provider, :userfiles => [create(:userfile)])
      expect{ destroyed_provider.destroy }.to raise_error(ActiveRecord::DeleteRestrictionError)
    end
    it "should allow desctruction if no associated userfiles still exist" do
      destroyed_provider = create(:data_provider)
      expect { destroyed_provider.destroy }.to change{ DataProvider.count }.by(-1)
    end
  end

  describe "#cache_md5" do
    before(:each) do
      allow(DataProvider).to receive(:cache_rootdir).and_return("cache")
      DataProvider.class_variable_set("@@key", nil)
    end

    it "should get md5 from file, if it exists" do
      allow(File).to receive(:exist?).and_return(true)
      expect(File).to receive(:read).and_return("XYZ")
      expect(DataProvider.cache_md5).to eq("XYZ")
    end

    it "should create the md5 file, if it does not exist" do
      allow(File).to receive(:exist?).and_return(false)
      allow(IO).to receive(:sysopen)
      fh = double("file_handle").as_null_object
      expect(IO).to receive(:open).and_return(fh)
      DataProvider.cache_md5
    end

    context "when creating the file fails" do
      before(:each) do
        allow(IO).to receive(:sysopen).and_raise(StandardError)
      end
      it "should raise an exception if the file doesn't exist" do
        allow(File).to receive(:exist?).and_return(false)
        expect {DataProvider.cache_md5}.to raise_error
      end
      context "if the file already exist" do
        let(:key) {double("key", :blank? => false).as_null_object}
        before(:each) do
          allow(File).to receive(:exist?).and_return(false, true)
          allow(DataProvider).to receive(:sleep)
          allow(File).to receive(:read).and_return(key)
        end
        it "should read the file" do
          expect(File).to receive(:read).and_return(key)
          DataProvider.cache_md5
        end
        it "should raise an exception if the key is blank" do
          allow(key).to receive(:blank?).and_return(true)
          expect {DataProvider.cache_md5}.to raise_error
        end
      end
    end
  end

  describe "#cache_revision_of_last_init" do
    let(:cache_rev)       { "1234-12-12" }
    before(:each) do
      allow(DataProvider).to receive(:cache_rootdir).and_return("cache")
      allow(DataProvider).to receive(:class_variable_defined?).and_return(false)
      allow(DataProvider).to receive(:this_is_a_proper_cache_dir!)
      allow(File).to         receive(:exist?).and_return(true)
      allow(File).to         receive(:read).and_return(cache_rev)
    end
    it "should check if the cache revision variable is already defined" do
      DataProvider.class_variable_set("@@cache_rev", Time.now.to_s)
      expect(DataProvider).to receive(:class_variable_defined?).and_return(true)
      DataProvider.cache_revision_of_last_init
    end
    it "should check if the cache dir is valid" do
      expect(DataProvider).to receive(:this_is_a_proper_cache_dir!).and_return(true)
      DataProvider.cache_revision_of_last_init
    end
    it "should check if the information already exists in a file" do
      expect(File).to receive(:exist?).and_return(true)
      DataProvider.cache_revision_of_last_init
    end
    it "should read information from the file if it exists" do
      expect(File).to receive(:read).and_return(cache_rev)
      DataProvider.cache_revision_of_last_init
    end
    context "when the information does not already exist in a file" do
      let(:file_descriptor) {double("fd").as_null_object}
      let(:file_handle)     {double("fh").as_null_object}
      before(:each) do
        allow(File).to receive(:exist?).and_return(false)
        allow(DataProvider).to receive_message_chain(:revision_info).and_return(double("rev_info").as_null_object)
        allow(IO).to receive(:sysopen).and_return(file_descriptor)
        allow(IO).to receive(:open).and_return(file_handle)
      end
      it "should open a file" do
        expect(IO).to receive(:open).and_return(file_handle)
        DataProvider.cache_revision_of_last_init
      end
      it "should attempt to write to the file" do
        expect(file_handle).to receive(:syswrite)
        DataProvider.cache_revision_of_last_init
      end
      it "should close the file" do
        expect(file_handle).to receive(:close)
        DataProvider.cache_revision_of_last_init
      end
      context "when the write fails" do
        before(:each) do
          allow(IO).to receive(:sysopen).and_raise(StandardError)
        end
        it "should raise an exception if the file does not exist" do
          allow(File).to receive(:exist?).and_return(false)
          expect {DataProvider.cache_revision_of_last_init}.to raise_error
        end
        context "because the file was just created" do
          before(:each) do
            allow(File).to receive(:exist?).and_return(false, true)
            allow(DataProvider).to receive(:sleep)
          end
          it "should read the file" do
            expect(File).to receive(:read).and_return(cache_rev)
            DataProvider.cache_revision_of_last_init
          end
          it "should raise an exception if the revision info is blank" do
            allow(cache_rev).to receive(:blank?).and_return(true)
            expect {DataProvider.cache_revision_of_last_init}.to raise_error
          end
        end
      end
    end
  end

  describe "#this_is_a_proper_cache_dir!" do
    let(:cache_root) { "/cache_root" }
    before(:each) do
      allow(File).to receive(:directory?).and_return(true)
      allow(File).to receive(:readable?).and_return(true)
      allow(File).to receive(:writable?).and_return(true)
      allow(File).to receive(:exist?).and_return(false)
      allow(Dir).to receive(:entries).and_return([])
    end
    it "should return true if all goes well" do
      expect(DataProvider.this_is_a_proper_cache_dir!(cache_root)).to be_truthy
    end
    it "should raise an exception if the cache root is blank" do
      expect {DataProvider.this_is_a_proper_cache_dir!("")}.to raise_error
    end
    it "should raise an exception if the cache root is a system tmp directory" do
      expect {DataProvider.this_is_a_proper_cache_dir!("/tmp")}.to raise_error
    end
    it "should return true if told not to check the file system, even if cache root doesn't exist" do
      allow(File).to receive(:directory?).and_return(false)
      expect(DataProvider.this_is_a_proper_cache_dir!(cache_root, :local => false)).to be_truthy
    end
    it "should raise an exception if the cache root doesn't exist" do
      allow(File).to receive(:directory?).and_return(false)
      expect {DataProvider.this_is_a_proper_cache_dir!(cache_root)}.to raise_error
    end
    it "should raise an exception if the cache root isn't readable" do
      allow(File).to receive(:readable?).and_return(false)
      expect {DataProvider.this_is_a_proper_cache_dir!(cache_root)}.to raise_error
    end
    it "should raise an exception if the cache root isn't writable" do
      allow(File).to receive(:writable?).and_return(false)
      expect {DataProvider.this_is_a_proper_cache_dir!(cache_root)}.to raise_error
    end
    it "should return true if the revision file exists" do
      allow(File).to receive(:exists?).and_return(true)
      expect(DataProvider.this_is_a_proper_cache_dir!(cache_root)).to be_truthy
    end
    it "should raise an exception if unable to read the contents of the cache root" do
      allow(Dir).to receive(:entries).and_return(nil)
      expect {DataProvider.this_is_a_proper_cache_dir!(cache_root)}.to raise_error
    end
    it "should raise an exception if the cache root is not empty" do
      allow(Dir).to receive(:entries).and_return(["file1", "file2"])
      expect {DataProvider.this_is_a_proper_cache_dir!(cache_root)}.to raise_error
    end
  end

  describe "#cache_rootdir" do
    before(:each) do
      @old_cache_rootdir = DataProvider.instance_eval { @cache_rootdir}
      DataProvider.instance_eval { @cache_rootdir = nil }
    end
    after(:each) do
      DataProvider.instance_eval { @cache_rootdir = @old_cache_rootdir }
    end
    it "should return the app's cache directory" do
      current_resource = double("current_ressource")
      allow(RemoteResource).to receive(:current_resource).and_return(current_resource)
      expect(current_resource).to receive(:dp_cache_dir).and_return("cache_dir")
      DataProvider.cache_rootdir
    end
    it "should raise an exception if the cache directory is blank" do
      allow(RemoteResource).to receive_message_chain(:current_resource, :dp_cache_dir).and_return("")
      expect {DataProvider.cache_rootdir}.to raise_error
    end
    it "should raise an exception if the cache directory is not a string or a path" do
      allow(RemoteResource).to receive_message_chain(:current_resource, :dp_cache_dir).and_return(123)
      expect {DataProvider.cache_rootdir}.to raise_error
    end
  end

  describe "#rsync_ignore_patterns" do
    it "should return the app's rsync ignore patterns" do
      current_resource = double("current_ressource")
      allow(RemoteResource).to receive(:current_resource).and_return(current_resource)
      expect(current_resource).to receive(:dp_ignore_patterns)
      DataProvider.instance_variable_set("@ig_patterns", nil)
      DataProvider.rsync_ignore_patterns
    end
  end
end

