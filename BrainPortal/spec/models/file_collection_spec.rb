
#
# CBRAIN Project
#
# FileCollection spec
#
# Original author: Natacha Beck
#
# $Id$
#


require 'spec_helper'

describe FileCollection do
  let(:provider) {Factory.create(:data_provider, :online => true, :read_only => false)}
  let(:file_collection) {Factory.create(:file_collection, :data_provider_id => provider.id) }
  
  describe "#content" do

    context "with options[:collection_file]" do
      before(:each) do
        File.stub!(:exist?).and_return(true)
        File.stub!(:readable?).and_return(true)
        File.stub!(:directory?).and_return(false)
        File.stub!(:symlink?).and_return(false)
      end
      
      it "should set status to 404 if path_string contain '..'" do
        a = double("cache_path")
        file_collection.stub_chain(:cache_full_path, :parent).and_return(a)
        a.should_receive(:+).with("").and_return("")
        file_collection.content(:collection_file => '../path')
      end

      it "should set sendfile to given path if we have a readable file" do
        file_collection.stub_chain(:cache_full_path, :parent).and_return("")
        file_collection.content(:collection_file => 'path')[:sendfile].should == 'path'
      end

      it "should set status to 404 if we have a file does not exist" do
        File.stub!(:exist?).and_return(false)
        file_collection.content(:collection_file => 'path')[:status].should == '404'
      end

      it "should set status to 404 if we have a file does not readable" do
        File.stub!(:readable?).and_return(false)
        file_collection.content(:collection_file => 'path')[:status].should == '404'
      end

      it "should set status to 404 if we have a directory" do
        File.stub!(:directory?).and_return(true)
        file_collection.content(:collection_file => 'path')[:status].should == '404'
      end

      it "should set status to 404 if we have a symlink" do
        File.stub!(:symlink?).and_return(true)
        file_collection.content(:collection_file => 'path')[:status].should == '404'
      end
    end

    context "without options[:collection_file]" do
      it "should set text with an error message if exception is a Net::SFTP::Exception" do
        File.stub!(:exist?).and_raise(Net::SFTP::Exception)
        file_collection.content(:collection_file => 'path')[:text].should =~ /Error loading/ 
      end
        
      it "should set text with an error message if exception.message contain Net::SFTP" do
        File.stub!(:exist?).and_raise(ZeroDivisionError.new("Net::SFTP"))
        file_collection.content(:collection_file => 'path')[:text].should =~ /Error loading/
      end
      
      it "should raise an error if exception is not a Net::SFTP::Exception or exception.error don't contain Net::SFTP" do 
        File.stub!(:exist?).and_raise(ZeroDivisionError)
        lambda{ file_collection.content(:collection_file => 'path')}.should raise_error()
      end
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
    let(:merge_collection) { Factory.create(:file_collection, :data_provider_id => provider.id) }
    let(:file_collection1) { mock_model(FileCollection, :size => 1024, :num_files => 2).as_null_object}
    let(:file_collection2) { mock_model(FileCollection, :size => 1024, :num_files => 1).as_null_object}
    
    before(:each) do
      file_collection1.stub!(:list_files).and_return([file_info1,file_info2])
      file_collection2.stub!(:list_files).and_return([file_info3])
      File.stub!(:directory?).and_return(true)
      FileUtils.stub!(:cp_r)      
      merge_collection.stub!(:cache_prepare)
      merge_collection.stub!(:sync_to_cache)
      merge_collection.stub!(:sync_to_provider)
      merge_collection.stub!(:save)
    end
    
    it "should return :collision if the collection share common file names" do
      file_collection2.stub!(:list_files).and_return([file_info2])
      merge_collection.merge_collections([file_collection1,file_collection2]).should be == :collision
    end

    it "should return :succes if all works correctly" do
      merge_collection.merge_collections([file_collection1,file_collection2]).should be == :success
    end

    it "should update num_files when merge is done" do
      final_numfiles = file_collection1.num_files + file_collection2.num_files                   
      merge_collection.merge_collections([file_collection1,file_collection2])
      merge_collection.reload
      merge_collection.num_files.should be == final_numfiles
    end
 
    it "should update size when merge is done" do
      final_size = file_collection1.size + file_collection2.size                   
      merge_collection.merge_collections([file_collection1,file_collection2])
      merge_collection.reload
      merge_collection.size.should be == final_size
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
