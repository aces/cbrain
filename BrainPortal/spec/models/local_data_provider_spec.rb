
#
# CBRAIN Project
#
# LocalDataProvider Spec 
#
# Original author: Natacha Beck
#
# $Id$
#


require 'spec_helper'

describe LocalDataProvider do
  let(:local_data_provider) {Factory.create(:local_data_provider)}
  let(:userfile) {Factory.create(:userfile, :data_provider => local_data_provider)}

  describe "#is_fast_syncing?" do
    
    it "should return true local data providers are considered fast syncing" do
      local_data_provider.is_fast_syncing?.should be_true
    end  
  end

  describe "#provider_full_path" do

    it "should call cache_full_path" do
      local_data_provider.should_receive(:cache_full_path).once
      local_data_provider.provider_full_path(userfile)
    end
  end

  describe "#impl_is_alive?" do
    
    it "should return true if remote_dir is a directory" do
      File.stub!(:directory?).and_return(true)
      local_data_provider.impl_is_alive?.should be_true
    end

    it "should return false if remote_dir is not a directory" do
      File.stub!(:directory?).and_return(false)
      local_data_provider.impl_is_alive?.should be_false
    end
  end

  describe "#impl_sync_to_cache" do
    
    it "should return true if all works correctly" do
      local_data_provider.should be_true
    end
  end

  describe "#impl_sync_to_provider" do
    
    it "should return true if all works correctly" do                   
      local_data_provider.should be_true
    end
  end

  describe "#impl_provider_list_all" do

    it "should always raise a cb_error" do
      lambda{local_data_provider.impl_provider_list_all}.should raise_error
    end
  end

  describe "#provider_readhandle" do

    it "should call cache_readhandle" do 
      local_data_provider.should_receive(:cache_readhandle).once
      local_data_provider.provider_readhandle(userfile)
    end
  end

  describe "#impl_provider_collection_index" do

    it "should call cache_collection_index" do 
      local_data_provider.should_receive(:cache_collection_index).once
      local_data_provider.impl_provider_collection_index(userfile)
    end
  end
end
