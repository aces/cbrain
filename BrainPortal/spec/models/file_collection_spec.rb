
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

describe FileCollection do
  let(:provider) {Factory.create(:data_provider, :online => true, :read_only => false)}
  let(:file_collection) {Factory.create(:file_collection, :data_provider_id => provider.id) }
  
  describe "#collection_file" do
    before(:each) do
      file_collection.stub_chain(:list_files, :find).and_return(true)        
      File.stub!(:exist?).and_return(true)
      File.stub!(:readable?).and_return(true)
      File.stub!(:directory?).and_return(false)
      File.stub!(:symlink?).and_return(false)
    end
    
    it "should return nil if collection file not in the collection's list of files" do
      file_collection.stub_chain(:list_files, :find).and_return(nil)
      file_collection.collection_file('path').should be_nil
    end
    
    it "should return the full path of the collection file if it exists" do
      base_path = 'base_path/'
      rel_path  = 'path'
      file_collection.stub_chain(:cache_full_path, :parent).and_return(base_path)
      file_collection.collection_file(rel_path).should == base_path + rel_path
    end
    
    it "should return nil if we have a file does not exist" do
      File.stub!(:exist?).and_return(false)
      file_collection.collection_file('path').should be_nil
    end
    
    it "should return nil if we have a file does not readable" do
      File.stub!(:readable?).and_return(false)
      file_collection.collection_file('path').should be_nil
    end
    
    it "should return nil if we have a directory" do
      File.stub!(:directory?).and_return(true)
      file_collection.collection_file('path').should be_nil
    end
    
    it "should return nil if we have a symlink" do
      File.stub!(:symlink?).and_return(true)
      file_collection.collection_file('path').should be_nil
    end
  end

  describe "#extract_collection_from_archive_file" do
    before(:each) do
      FileCollection.stub!(:cache_prepare).and_return(true)
      File.stub!(:exist?).and_return(true)
      File.stub!(:directory?).and_return(true)
      Dir.stub!(:chdir).and_yield
      file_collection.stub!(:remove_unwanted_files)
      file_collection.stub!(:sync_to_provider)
      file_collection.stub!(:set_size!)
      file_collection.stub!(:save)
    end
    
    it "should execute 'gunzip' if archive is a *.tar.gz" do
      file_collection.should_receive(:system).with(/^gunzip/)
      file_collection.extract_collection_from_archive_file("dir.tar.gz")
    end

    it "should execute 'gunzip' if archive is a *.tgz" do
      file_collection.should_receive(:system).with(/^gunzip/)
      file_collection.extract_collection_from_archive_file("dir.tgz")
    end

    it "should execute 'tar -xf' if archive is a *.tar" do
      file_collection.should_receive(:system).with(/^tar -xf/)
      file_collection.extract_collection_from_archive_file("dir.tar")
    end

    it "should execute 'unzip' if archive is a *.zip" do
      file_collection.should_receive(:system).with(/^unzip/)
      file_collection.extract_collection_from_archive_file("dir.zip")
    end

    it "should raise an exception if archive have an unknown extension" do
      lambda{
        file_collection.extract_collection_from_archive_file("dir.unknown")
      }.should raise_error
    end
  end

  describe "#format_size" do
    
    it "should format size with following format '\\s+size\\s+\(num_files\)'" do
      file_collection.size      = 107246558
      file_collection.num_files = 5
      file_collection.format_size.should  =~ /\s+#\d+\.?\d?\s+K|M|GB\s+\(#{file_collection.num_files}\s+\files\)/
    end
  end

  describe "#set_size" do
    
    let(:file_info1) {DataProvider::FileInfo.new}
    let(:file_info2) {DataProvider::FileInfo.new}
    
    before(:each) do
      file_info1.size = file_info2.size = 1024
      file_collection.stub!(:list_files).and_return([file_info1,file_info2])
    end
    
    it "should set size with the size of this collection" do
      file_collection.set_size!
      file_collection.reload
      file_collection.size.should == 2048
    end
    it "should set num_files with the number of files in this collection" do
      file_collection.set_size!
      file_collection.reload
      file_collection.num_files.should == file_collection.list_files.size
    end
    it "should return true if all works correctly" do
      file_collection.set_size!.should be_true
    end
  end

  describe "#merge_collections" do
    
    let(:file_info1) { double("file_info1", :name => "name1")}
    let(:file_info2) { double("file_info2", :name => "name2")}
    let(:file_info3) { double("file_info3", :name => "name3")}
    let(:file_collection1) { mock_model(FileCollection, :size => 1024, :num_files => 2).as_null_object}
    let(:file_collection2) { mock_model(FileCollection, :size => 1024, :num_files => 1).as_null_object}
    
    before(:each) do
      file_collection1.stub!(:list_files).and_return([file_info1,file_info2])
      file_collection2.stub!(:list_files).and_return([file_info3])
      File.stub!(:directory?).and_return(true)
      FileUtils.stub!(:cp_r)      
      file_collection.stub!(:cache_prepare)
      file_collection.stub!(:sync_to_cache)
      file_collection.stub!(:sync_to_provider)
      file_collection.stub!(:save)
    end
    
    it "should return :collision if the collection share common file names" do
      file_collection2.stub!(:list_files).and_return([file_info2])
      file_collection.merge_collections([file_collection1,file_collection2]).should be == :collision
    end
  
    it "should return :succes if all works correctly" do
      file_collection.merge_collections([file_collection1,file_collection2]).should be == :success
    end
  
    it "should update num_files when merge is done" do
      final_numfiles = file_collection1.num_files + file_collection2.num_files                   
      file_collection.merge_collections([file_collection1,file_collection2])
      file_collection.reload
      file_collection.num_files.should be == final_numfiles
    end
   
    it "should update size when merge is done" do
      final_size = file_collection1.size + file_collection2.size                   
      file_collection.merge_collections([file_collection1,file_collection2])
      file_collection.reload
      file_collection.size.should be == final_size
    end
  end
  
  describe "#list_first_level_dirs" do
    
    it "should call IO.popen" do
      a = double("cache_path")
      file_collection.stub_chain(:cache_full_path, :parent).and_return(a)
      Dir.stub!(:chdir).and_yield
      IO.should_receive(:popen).with(/^find/).and_yield(double("fh", :readlines => [] ))
      file_collection.list_first_level_dirs
    end
  end
  
  describe "#remove_unwanted_files" do
    
    let(:file_info1) {DataProvider::FileInfo.new}
    
    before(:each) do
      a = double("cache_path")
      file_collection.stub!(:cache_full_path).and_return(a)
      Dir.stub!(:chdir).and_yield
    end
   
    it "should delete file if it match with ._*" do
      Find.stub(:find).and_yield("._")
      File.should_receive(:delete)
      file_collection.remove_unwanted_files
    end
    
    it "should delete file if it .DS_Store" do
      Find.stub(:find).and_yield(".DS_Store")
      File.should_receive(:delete)
      file_collection.remove_unwanted_files
    end

    it "should not delete file if is not ._ or not .DS_Store file" do
      Find.stub(:find).and_yield(".")
      File.should_not_receive(:delete)
      file_collection.remove_unwanted_files
    end
  end
  
end               

