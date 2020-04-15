
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

describe FileCollection do
  let(:provider)        { create(:ssh_data_provider, :online => true, :read_only => false) }
  let(:file_collection) { create(:file_collection, :data_provider => provider) }
  let(:stat)            { double("stat").as_null_object }
  let(:fullpath)        { double("fullpath").as_null_object }
  cacheroot       = Pathname.new("cacheroot")
  cache_full_path = cacheroot + "path"

  before(:each) do
    allow(File).to            receive(:exist?).and_return(true)
    allow(file_collection).to receive(:cache_full_path).and_return(cache_full_path)
    allow(provider).to        receive(:cache_prepare).and_return(true)
  end

  describe "#collection_file" do
    before(:each) do
      allow(stat).to          receive(:readable?).and_return(true)
      allow(stat).to          receive(:file?).and_return(true)
      allow(stat).to          receive(:symlink?).and_return(false)
      allow(File).to          receive(:stat).and_return(stat)
      allow(cacheroot).to     receive(:+).and_return(cache_full_path)
      allow(cache_full_path).to receive(:parent).and_return(cacheroot)
      allow(cache_full_path).to receive(:realdirpath).and_return(cache_full_path)
    end

    it "should return nil if collection file not in the collection's list of files" do
      allow(cache_full_path).to receive(:realdirpath).and_return(nil)
      expect(file_collection.collection_file('bad')).to be_nil
    end

    it "should return the full path of the collection file if it exists" do
      expect(file_collection.collection_file('path')).to eq(cache_full_path)
    end

    it "should return nil if we have a file does not exist" do
      allow(File).to          receive(:stat).and_return(nil)
      expect(file_collection.collection_file('path')).to be_nil
    end

    it "should return nil if we have a file does not readable" do
      allow(stat).to receive(:readable?).and_return(false)
      expect(file_collection.collection_file('path')).to be_nil
    end

    it "should return nil if we have a directory" do
      allow(stat).to receive(:file?).and_return(false)
      expect(file_collection.collection_file('path')).to be_nil
    end

    it "should return nil if we have a symlink" do
      allow(stat).to receive(:symlink?).and_return(true)
      expect(file_collection.collection_file('path')).to be_nil
    end
  end

  describe "#extract_collection_from_archive_file" do
    before(:each) do
      allow(File).to            receive(:directory?).and_return(true)
      allow(Dir).to             receive(:chdir).and_yield
      allow(file_collection).to receive(:cache_prepare).and_return(true)
      allow(file_collection).to receive(:remove_unwanted_files)
      allow(file_collection).to receive(:sync_to_provider)
      allow(file_collection).to receive(:set_size!)
      allow(file_collection).to receive(:save)
    end

    it "should execute 'gunzip' if archive is a *.tar.gz" do
      expect(file_collection).to receive(:system).with(/^gunzip/)
      file_collection.extract_collection_from_archive_file("dir.tar.gz")
    end

    it "should execute 'gunzip' if archive is a *.tgz" do
      expect(file_collection).to receive(:system).with(/^gunzip/)
      file_collection.extract_collection_from_archive_file("dir.tgz")
    end

    it "should execute 'tar -xf' if archive is a *.tar" do
      expect(file_collection).to receive(:system).with(/^tar -xf/)
      file_collection.extract_collection_from_archive_file("dir.tar")
    end

    it "should execute 'unzip' if archive is a *.zip" do
      expect(file_collection).to receive(:system).with(/^unzip/)
      file_collection.extract_collection_from_archive_file("dir.zip")
    end

    it "should raise an exception if archive have an unknown extension" do
      expect{
        file_collection.extract_collection_from_archive_file("dir.unknown")
      }.to raise_error(CbrainError, /Cannot extract files/)
    end
  end

  describe "#set_size" do

    let(:file_info1) {FileInfo.new}
    let(:file_info2) {FileInfo.new}

    before(:each) do
      file_info1.size = file_info2.size = 1024
      allow(file_collection).to receive(:list_files).and_return([file_info1,file_info2])
    end

    it "should set size with the size of this collection" do
      file_collection.set_size!
      file_collection.reload
      expect(file_collection.size).to eq(2048)
    end
    it "should set num_files with the number of files in this collection" do
      file_collection.set_size!
      file_collection.reload
      expect(file_collection.num_files).to eq(file_collection.list_files.size)
    end
    it "should return true if all works correctly" do
      expect(file_collection.set_size!).to be_truthy
    end
  end

  describe "#merge_collections" do

    let(:file_info1) { double("file_info1", :name => "name1")}
    let(:file_info2) { double("file_info2", :name => "name2")}
    let(:file_info3) { double("file_info3", :name => "name3")}
    let(:file_collection1) { mock_model(FileCollection, :size => 1024, :num_files => 2).as_null_object}
    let(:file_collection2) { mock_model(FileCollection, :size => 1024, :num_files => 1).as_null_object}

    before(:each) do
      allow(file_collection1).to receive(:list_files).and_return([file_info1,file_info2])
      allow(file_collection2).to receive(:list_files).and_return([file_info3])
      allow(File).to receive(:directory?).and_return(true)
      allow(FileUtils).to receive(:cp_r)
      allow(file_collection).to receive(:cache_prepare)
      allow(file_collection).to receive(:sync_to_cache)
      allow(file_collection).to receive(:sync_to_provider)
      allow(file_collection).to receive(:save)
    end

    it "should return :collision if the collection share common file names" do
      allow(file_collection2).to receive(:list_files).and_return([file_info2])
      expect(file_collection.merge_collections([file_collection1,file_collection2])).to eq(:collision)
    end

    it "should return :succes if all works correctly" do
      expect(file_collection.merge_collections([file_collection1,file_collection2])).to eq(:success)
    end

    it "should update num_files when merge is done" do
      final_numfiles = file_collection1.num_files + file_collection2.num_files
      file_collection.merge_collections([file_collection1,file_collection2])
      file_collection.reload
      expect(file_collection.num_files).to eq(final_numfiles)
    end

    it "should update size when merge is done" do
      final_size = file_collection1.size + file_collection2.size
      file_collection.merge_collections([file_collection1,file_collection2])
      file_collection.reload
      expect(file_collection.size).to eq(final_size)
    end
  end

  describe "#list_first_level_dirs" do

    it "should call IO.popen" do
      a = double("cache_path")
      allow(file_collection).to receive_message_chain(:cache_full_path, :parent).and_return(a)
      allow(Dir).to receive(:chdir).and_yield
      expect(IO).to receive(:popen).with(/^find/).and_yield(double("fh", :readlines => [] ))
      file_collection.list_first_level_dirs
    end
  end

  describe "#remove_unwanted_files" do

    let(:file_info1) {FileInfo.new}

    before(:each) do
      a = double("cache_path")
      allow(file_collection).to receive(:cache_full_path).and_return(a)
      allow(Dir).to receive(:chdir).and_yield
    end

    it "should delete file if it match with ._*" do
      allow(Find).to receive(:find).and_yield("._")
      expect(File).to receive(:delete)
      file_collection.remove_unwanted_files
    end

    it "should delete file if it .DS_Store" do
      allow(Find).to receive(:find).and_yield(".DS_Store")
      expect(File).to receive(:delete)
      file_collection.remove_unwanted_files
    end

    it "should not delete file if is not ._ or not .DS_Store file" do
      allow(Find).to receive(:find).and_yield(".")
      expect(File).not_to receive(:delete)
      file_collection.remove_unwanted_files
    end
  end

end

