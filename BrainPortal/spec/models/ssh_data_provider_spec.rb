
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

describe SshDataProvider do
  let(:provider)        { create(:ssh_data_provider) }
  let(:ssh_master)      { double("master").as_null_object }
  let(:single_file)     { mock_model(SingleFile, :name => "single_file").as_null_object }
  let(:file_collection) { mock_model(FileCollection, :name => "file_collection").as_null_object }

  before(:each) do
    allow(provider).to   receive(:remote_dir).and_return("remote_dir")
    allow(provider).to   receive(:cache_full_path).and_return(Pathname.new("cache_path"))
    allow(provider).to   receive(:bash_this).and_return("")
    allow(provider).to   receive(:mkdir_cache_subdirs)
    allow(provider).to   receive(:master).and_return(ssh_master)
    allow(SshMaster).to  receive(:find_or_create).and_return(ssh_master)
    allow(ssh_master).to receive(:is_alive?).and_return(true)
  end
  describe "#impl_is_alive?" do
    it "should return false if ssh master is not alive" do
      allow(ssh_master).to receive(:is_alive?).and_return(false)
      expect(provider.impl_is_alive?).to be_falsey
    end
    it "should execute a bash command" do
      allow(ssh_master).to receive(:is_alive?).and_return(true)
      expect(provider).to receive(:remote_bash_this)
      provider.impl_is_alive?
    end
    it "should return true if the bash command returns the expected string" do
      allow(provider).to receive(:remote_bash_this).and_return("OK-Dir")
      expect(provider.impl_is_alive?).to be_truthy
    end
    it "should return false if the bash command returns something other than the expected string" do
      allow(provider).to receive(:remote_bash_this).and_return("ERRROR")
      expect(provider.impl_is_alive?).to be_falsey
    end
  end
  describe "#is_browsable?" do
    it "should return true" do
      expect(provider.is_browsable?).to be_truthy
    end
  end
  describe "#allow_file_owner_change?" do
    it "should return true" do
      expect(provider.allow_file_owner_change?).to be_truthy
    end
  end
  describe "#impl_sync_to_cache" do
    before(:each) do
      allow(Dir).to receive(:mkdir)
      allow(File).to receive(:directory?).and_return(true)
      allow(File).to receive(:exist?).and_return(true)
      allow(provider).to receive(:rsync_select_pattern_options).and_return(nil)
    end
    context "for a FileCollection" do
      it "should check if the cache directory already exists" do
        expect(File).to receive(:directory?).and_return(true)
        provider.impl_sync_to_cache(file_collection)
      end
      it "should make a directory for a FileCollection if it doesn't exist" do
        allow(File).to receive(:directory?).and_return(false)
        expect(Dir).to receive(:mkdir)
        provider.impl_sync_to_cache(file_collection)
      end
      it "should not make a directory for a FileCollection if it already exist" do
        allow(File).to receive(:directory?).and_return(true)
        expect(Dir).not_to receive(:mkdir)
        provider.impl_sync_to_cache(file_collection)
      end
    end
    it "should not make a directory for a SingleFile" do
      allow(File).to receive(:directory?).and_return(false)
      expect(Dir).not_to receive(:mkdir)
      provider.impl_sync_to_cache(single_file)
    end
    it "should execute a bash command" do
      expect(provider).to receive(:bash_this)
      provider.impl_sync_to_cache(single_file)
    end
    it "should raise an error if the bash command returns something" do
      allow(provider).to receive(:bash_this).and_return("Error")
      expect { provider.impl_sync_to_cache(single_file) }.to raise_error(CbrainError, /syncing userfile/)
    end
    it "should raise an error if the file wasn't created" do
      allow(File).to receive(:exist?).and_return(false)
      expect { provider.impl_sync_to_cache(single_file) }.to raise_error(CbrainError, /syncing userfile/)
    end
    it "should return true if everything goes well" do
      expect(provider.impl_sync_to_cache(single_file)).to be_truthy
    end
  end
  describe "#impl_sync_to_provider" do
    before(:each) do
      allow(provider).to receive(:bash_this).and_return("")
      allow(File).to receive(:exist?).and_return(true)
      allow(provider).to receive(:provider_file_exists?).and_return("file")
    end
    it "should raise an error if the file doesn't exist" do
      allow(File).to receive(:exist?).and_return(false)
      expect { provider.impl_sync_to_provider(single_file) }.to raise_error(CbrainError, /does not exist/)
    end
    it "should execute an rsync command" do
      expect(provider).to receive(:bash_this).and_return("")
      provider.impl_sync_to_provider(single_file)
    end
    it "should raise an error if rsync returns something" do
      allow(provider).to receive(:bash_this).and_return("Error")
      expect { provider.impl_sync_to_provider(single_file) }.to raise_error(CbrainError, /syncing userfile/)
    end
    it "should raise an error the file doesn't exist on the provider" do
      allow(provider).to receive(:provider_file_exists?).and_return("")
      expect { provider.impl_sync_to_provider(single_file) }.to raise_error(CbrainError, /syncing userfile/)
    end
    it "should return true if everything goes well" do
      expect(provider.impl_sync_to_provider(single_file)).to be_truthy
    end
  end
  describe "#impl_provider_erase" do
    it "should execute rm command" do
      expect(provider).to receive(:remote_bash_this).with(/rm -rf/, any_args)
      provider.impl_provider_erase(single_file)
    end
    it "should return true" do
      expect(provider.impl_provider_erase(single_file)).to be_truthy
    end
  end
  describe "#impl_provider_rename" do
    let(:sftp) { double("sftp").as_null_object }

    before(:each) do
      allow(Net::SFTP).to receive(:start).and_yield(sftp)
      allow(sftp).to receive(:lstat!).and_raise(StandardError)
    end
    it "should start an SFTP session" do
      expect(Net::SFTP).to receive(:start)
      provider.impl_provider_rename(single_file, "new_name")
    end
    it "should check for collision" do
      expect(sftp).to receive(:lstat!)
      provider.impl_provider_rename(single_file, "new_name")
    end
    it "should return false if there is a collision" do
      allow(sftp).to receive(:lstat!).and_return(true)
      expect(provider.impl_provider_rename(single_file, "new_name")).to be_falsey
    end
    it "should rename the file" do
      expect(sftp).to receive(:rename!)
      provider.impl_provider_rename(single_file, "new_name")
    end
    it "should return true if the rename is successful" do
      expect(provider.impl_provider_rename(single_file, "new_name")).to be_truthy
    end
    it "should return false if rename fails" do
      allow(sftp).to receive(:rename!).and_raise(StandardError)
      expect(provider.impl_provider_rename(single_file, "new_name")).to be_falsey
    end
  end
  describe "#impl_provider_readhandle" do
    it "should open an ssh handle" do
      expect(IO).to receive(:popen)
      provider.impl_provider_readhandle(single_file)
    end
    it "should raise an exception if the file handle is invalid" do
      allow(IO).to receive(:popen).and_yield(double("fh", :eof? => true))
      expect { provider.impl_provider_readhandle(single_file) }.to raise_error(LocalJumpError, /no block given/)
    end
  end
  describe "#impl_provider_list_all" do
    let(:sftp)  { double("sftp").as_null_object }
    let(:entry) { double("entry").as_null_object }

    before(:each) do
      allow(Net::SFTP).to receive(:start).and_yield(sftp)
      allow(sftp).to      receive_message_chain(:dir, :foreach).and_yield(entry)
      allow(entry).to     receive(:attributes).and_return(double("atts", :symbolic_type => :regular).as_null_object)
    end
    it "should start an SFTP session" do
      expect(Net::SFTP).to receive(:start)
      provider.impl_provider_list_all
    end
    it "should iterate through the entries in the directory" do
      expect(sftp).to receive(:dir).and_return(double.as_null_object)
      provider.impl_provider_list_all
    end
    it "should extract the attributes for the entry" do
      expect(entry).to receive(:attributes)
      provider.impl_provider_list_all
    end
    it "should create a new FileInfo object" do
      expect(FileInfo).to receive(:new).and_return(double.as_null_object)
      provider.impl_provider_list_all
    end
    it "should return an array of FileInfo objects" do
      expect(provider.impl_provider_list_all.all? { |fi| fi.is_a?(FileInfo) }).to be_truthy
    end
  end
  describe "#browse_remote_dir" do
    it "should call remote_dir" do
      expect(provider).to receive(:remote_dir)
      provider.browse_remote_dir
    end
  end
  describe "#impl_provider_collection_index" do
    let(:sftp) { double("sftp", :dir => dir).as_null_object }
    let(:dir) { double("dir", :entries => [entry], :glob => [entry]).as_null_object }
    let(:entry) { double("entry").as_null_object }

    before(:each) do
      allow(Net::SFTP).to receive(:start).and_yield(sftp)
      allow(entry).to receive(:attributes).and_return(double("atts", :symbolic_type => :regular).as_null_object)
    end
    it "should start an SFTP session" do
      expect(Net::SFTP).to receive(:start)
      provider.impl_provider_collection_index(file_collection)
    end
    context "when given a file collectiion" do
      it "should glob all contents if given :all option" do
        expect(dir).to receive(:glob)
        provider.impl_provider_collection_index(file_collection, :all)
      end
      it "should list entries if given a directory" do
        expect(dir).to receive(:entries)
        provider.impl_provider_collection_index(file_collection, "dir")
      end
    end
    context "when given a single file" do
      it "should stat the file" do
        expect(sftp).to receive(:stat).and_return(double.as_null_object)
        provider.impl_provider_collection_index(single_file)
      end
      it "should Net:SFTP Name object if given a single file" do
        expect(sftp).to receive(:stat).and_yield({}).and_return(double.as_null_object)
        expect(Net::SFTP::Protocol::V01::Name).to receive(:new).and_return(double.as_null_object)
        provider.impl_provider_collection_index(single_file)
      end
    end
    it "should create a new FileInfo object" do
      expect(FileInfo).to receive(:new).and_return(double.as_null_object)
      provider.impl_provider_collection_index(file_collection)
    end
    it "should return an array of FileInfo objects" do
      expect(provider.impl_provider_collection_index(file_collection).all? { |fi| fi.is_a?(FileInfo) }).to be_truthy
    end
  end
  describe "#provider_full_path" do
    it "should combine the userfile name with the remote path" do
      userfile = double("userfile", :name => "basename")
      allow(provider).to receive(:remote_dir).and_return("remote_dir")
      expect(provider.provider_full_path(userfile)).to eq(Pathname.new("remote_dir") + "basename")
    end
  end
end

