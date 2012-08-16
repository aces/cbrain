
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

describe SshDataProvider do
  let(:provider) {Factory.create(:ssh_data_provider)}
  let(:ssh_master) {double("master").as_null_object}
  let(:single_file) { mock_model(SingleFile, :name => "single_file").as_null_object}
  let(:file_collection) { mock_model(FileCollection, :name => "file_collection").as_null_object}
  
  before(:each) do
    provider.stub!(:remote_dir).and_return("remote_dir")
    provider.stub!(:cache_full_path).and_return(Pathname.new("cache_path"))
    provider.stub!(:bash_this).and_return("")
    provider.stub!(:mkdir_cache_subdirs)
    provider.stub!(:master).and_return(ssh_master)
    SshMaster.stub!(:find_or_create).and_return(ssh_master)
    ssh_master.stub!(:is_alive?).and_return(true)
  end
  describe "#impl_is_alive?" do
    it "should return false if ssh master is not alive" do
      ssh_master.stub!(:is_alive?).and_return(false)
      provider.impl_is_alive?.should be_false
    end
    it "should execute a bash command" do
      ssh_master.stub!(:is_alive?).and_return(true)
      provider.should_receive(:remote_bash_this)
      provider.impl_is_alive?
    end
    it "should return true if the bash command returns the expected string" do
      provider.stub!(:remote_bash_this).and_return("OK-Dir")
      provider.impl_is_alive?.should be_true
    end
    it "should return false if the bash command returns something other than the expected string" do
      provider.stub!(:remote_bash_this).and_return("ERRROR")
      provider.impl_is_alive?.should be_false
    end
  end
  describe "#is_browsable?" do
    it "should return true" do
      provider.is_browsable?.should be_true
    end
  end
  describe "#allow_file_owner_change?" do
    it "should return true" do
      provider.allow_file_owner_change?.should be_true
    end
  end
  describe "#impl_sync_to_cache" do
    before(:each) do
      Dir.stub!(:mkdir)
      File.stub!(:directory?).and_return(true)
      File.stub!(:exist?).and_return(true)
    end
    context "for a FileCollection" do
      it "should check if the cache directory already exists" do
        File.should_receive(:directory?).and_return(true)
        provider.impl_sync_to_cache(file_collection)
      end    
      it "should make a directory for a FileCollection if it doesn't exist" do
        File.stub!(:directory?).and_return(false)
        Dir.should_receive(:mkdir)
        provider.impl_sync_to_cache(file_collection)
      end
      it "should not make a directory for a FileCollection if it already exist" do
        File.stub!(:directory?).and_return(true)
        Dir.should_not_receive(:mkdir)
        provider.impl_sync_to_cache(file_collection)
      end
    end
    it "should not make a directory for a SingleFile" do
      File.stub!(:directory?).and_return(false)
      Dir.should_not_receive(:mkdir)
      provider.impl_sync_to_cache(single_file)
    end
    it "should execute a bash command" do
      provider.should_receive(:bash_this)
      provider.impl_sync_to_cache(single_file)
    end
    it "should raise an error if the bash command returns something" do
      provider.stub!(:bash_this).and_return("Error")
      lambda { provider.impl_sync_to_cache(single_file) }.should raise_error
    end
    it "should raise an error if the file wasn't created" do
      File.stub!(:exist?).and_return(false)
      lambda { provider.impl_sync_to_cache(single_file) }.should raise_error
    end
    it "should return true if everything goes well" do
      provider.impl_sync_to_cache(single_file).should be_true
    end
  end
  describe "#impl_sync_to_provider" do
    before(:each) do
      provider.stub!(:bash_this).and_return("")
      File.stub!(:exist?).and_return(true)
      provider.stub!(:provider_file_exists?).and_return("file")
    end
    it "should raise an error if the file doesn't exist" do
      File.stub!(:exist?).and_return(false)
      lambda { provider.impl_sync_to_provider(single_file) }.should raise_error
    end
    it "should execute an rsync command" do
      provider.should_receive(:bash_this).and_return("")
      provider.impl_sync_to_provider(single_file)
    end
    it "should raise an error if rsync returns something" do
      provider.stub!(:bash_this).and_return("Error")
      lambda { provider.impl_sync_to_provider(single_file) }.should raise_error
    end
    it "should raise an error the file doesn't exist on the provider" do
      provider.stub!(:provider_file_exists?).and_return("")
      lambda { provider.impl_sync_to_provider(single_file) }.should raise_error
    end
    it "should return true if everything goes well" do
      provider.impl_sync_to_provider(single_file).should be_true
    end
  end
  describe "#impl_provider_erase" do
    it "should execute rm command" do
      provider.should_receive(:remote_bash_this).with(/rm -rf/)
      provider.impl_provider_erase(single_file)
    end
    it "should return true" do
      provider.impl_provider_erase(single_file).should be_true
    end
  end
  describe "#impl_provider_rename" do
    let(:sftp) { double("sftp").as_null_object }
    
    before(:each) do
      Net::SFTP.stub!(:start).and_yield(sftp)
      sftp.stub!(:lstat!).and_raise(StandardError)
    end
    it "should start an SFTP session" do
      Net::SFTP.should_receive(:start)
      provider.impl_provider_rename(single_file, "new_name")
    end
    it "should check for collision" do
      sftp.should_receive(:lstat!)
      provider.impl_provider_rename(single_file, "new_name")
    end
    it "should return false if there is a collision" do
      sftp.stub!(:lstat!).and_return(true)
      provider.impl_provider_rename(single_file, "new_name").should be_false
    end
    it "should rename the file" do
      sftp.should_receive(:rename!)
      provider.impl_provider_rename(single_file, "new_name")
    end
    it "should return true if the rename is succesful" do
      provider.impl_provider_rename(single_file, "new_name").should be_true
    end
    it "should return false if rename fails" do
      sftp.stub!(:rename!).and_raise(StandardError)
      provider.impl_provider_rename(single_file, "new_name").should be_false
    end
  end
  describe "#impl_provider_readhandle" do
    it "should open an ssh handle" do
      IO.should_receive(:popen)
      provider.impl_provider_readhandle(single_file)
    end
    it "should raise an exception if the file handle is invalid" do
      IO.stub!(:popen).and_yield(double("fh", :eof? => true))
      lambda { provider.impl_provider_readhandle(single_file) }.should raise_error
    end
  end
  describe "#impl_provider_list_all" do
    let(:sftp) { double("sftp").as_null_object }
    let(:entry) { double("entry").as_null_object }
    
    before(:each) do
      Net::SFTP.stub!(:start).and_yield(sftp)
      sftp.stub_chain(:dir, :foreach).and_yield(entry)
      entry.stub!(:attributes).and_return(double("atts", :symbolic_type => :regular).as_null_object)
    end
    it "should start an SFTP session" do
      Net::SFTP.should_receive(:start)
      provider.impl_provider_list_all
    end
    it "should iterate through the entries in the directory" do
      sftp.should_receive(:dir).and_return(double.as_null_object)
      provider.impl_provider_list_all
    end
    it "should extract the attributes for the entry" do
      entry.should_receive(:attributes)
      provider.impl_provider_list_all
    end
    it "should create a new FileInfo object" do
      DataProvider::FileInfo.should_receive(:new).and_return(double.as_null_object)
      provider.impl_provider_list_all
    end
    it "should return an array of FileInfo objects" do
      provider.impl_provider_list_all.all? { |fi| fi.is_a?(DataProvider::FileInfo) }.should be_true
    end
  end
  describe "#browse_remote_dir" do
    it "should call remote_dir" do
      provider.should_receive(:remote_dir)
      provider.browse_remote_dir
    end
  end
  describe "#impl_provider_collection_index" do
    let(:sftp) { double("sftp", :dir => dir).as_null_object }
    let(:dir) { double("dir", :entries => [entry], :glob => [entry]).as_null_object }
    let(:entry) { double("entry").as_null_object }
    
    before(:each) do
      Net::SFTP.stub!(:start).and_yield(sftp)
      entry.stub!(:attributes).and_return(double("atts", :symbolic_type => :regular).as_null_object)
    end
    it "should start an SFTP session" do
      Net::SFTP.should_receive(:start)
      provider.impl_provider_collection_index(file_collection)
    end
    context "when given a file collectiion" do
      it "should glob all contents if given :all option" do
        dir.should_receive(:glob)
        provider.impl_provider_collection_index(file_collection, :all)
      end
      it "should list entries if given a directory" do
        dir.should_receive(:entries)
        provider.impl_provider_collection_index(file_collection, "dir")
      end
    end
    context "when given a single file" do
      it "should stat the file" do
        sftp.should_receive(:stat).and_return(double.as_null_object)
        provider.impl_provider_collection_index(single_file)
      end
      it "should Net:SFTP Name object if given a single file" do
        sftp.should_receive(:stat).and_yield({}).and_return(double.as_null_object)
        Net::SFTP::Protocol::V01::Name.should_receive(:new).and_return(double.as_null_object)
        provider.impl_provider_collection_index(single_file)
      end
    end
    it "should create a new FileInfo object" do
      DataProvider::FileInfo.should_receive(:new).and_return(double.as_null_object)
      provider.impl_provider_collection_index(file_collection)
    end
    it "should return an array of FileInfo objects" do
      provider.impl_provider_collection_index(file_collection).all? { |fi| fi.is_a?(DataProvider::FileInfo) }.should be_true
    end
  end
  describe "#provider_full_path" do
    it "should combine the userfile name with the remote path" do
      userfile = double("userfile", :name => "basename")
      provider.stub!(:remote_dir).and_return("remote_dir")
      provider.provider_full_path(userfile).should == Pathname.new("remote_dir") + "basename"
    end
  end
end

