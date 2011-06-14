
#
# CBRAIN Project
#
# CbrainLocalDataProvider Spec 
#
# Original author: Natacha Beck
#
# $Id$
#


require 'spec_helper'

describe CbrainLocalDataProvider do
  let(:cbrain_local_data_provider) {Factory.create(:cbrain_local_data_provider, :remote_dir => "remote")}
  let(:userfile) {Factory.create(:userfile, :data_provider => cbrain_local_data_provider)}
  
  describe "#cache_prepare" do
    before(:each) do
      SyncStatus.stub!(:ready_to_modify_cache).and_yield      
    end
    
    it "should return true if all works correctly" do
      Dir.stub!(:mkdir)
      cbrain_local_data_provider.cache_prepare(userfile).should be_true
    end

    it "should call mkdir if new userdir not already a directory" do
      File.stub!(:directory?).and_return(false)
      Dir.should_receive(:mkdir).at_least(3)
      cbrain_local_data_provider.cache_prepare(userfile)
    end
    
    it "should not call mkdir if new userdir already exist" do
      File.stub!(:directory?).and_return(true)
      Dir.should_not_receive(:mkdir)
      cbrain_local_data_provider.cache_prepare(userfile)
    end
  end
  
  describe "#cache_full_path" do
    
    it "should return a Pathname containing full path" do
      cache_subdirs_from_name_values = ["146","22"] 
      cbrain_local_data_provider.stub!(:cache_subdirs_from_name).and_return(cache_subdirs_from_name_values)
      cache_full_path = Pathname.new("#{cbrain_local_data_provider.remote_dir}/#{userfile.user.login}/#{cache_subdirs_from_name_values[0]}/#{cache_subdirs_from_name_values[1]}/#{userfile.name}")
      cbrain_local_data_provider.cache_full_path(userfile).should be == cache_full_path
    end
  end

  describe "#cache_erase" do

    it "should call SyncStatus.ready_to_modify_cache" do
      SyncStatus.should_receive(:ready_to_modify_cache).once
      cbrain_local_data_provider.cache_erase(userfile)
    end
    
    it "should return true if all works correctly" do
      SyncStatus.stub!(:ready_to_modify_cache).and_yield      
      cbrain_local_data_provider.cache_erase(userfile).should be_true
    end 
  end

  describe "#impl_provider_erase" do
       
    it "should call FileUtils.remove_entry with cache_full_path and true" do
      FileUtils.should_receive(:remove_entry).once
      cbrain_local_data_provider.impl_provider_erase(userfile)
    end
    
    it "should return true if all works correctly" do
      FileUtils.stub!(:remove_entry)
      cbrain_local_data_provider.impl_provider_erase(userfile).should be_true
    end
  end

  describe "#impl_provider_rename" do
    before(:each) do
      Dir.stub!(:mkdir).and_return(true)
      File.stub!(:directory?)
      userfile.stub!(:cache_full_path)
      cbrain_local_data_provider.stub!(:cache_subdirs_from_name).and_return(["196","22"])
      FileUtils.stub!(:move).and_return(true)
    end

    it "should call FileUtils.remove_entry" do
      FileUtils.should_receive(:remove_entry).once
      cbrain_local_data_provider.impl_provider_rename(userfile,"new_name")
    end 

    it "should return false if FileUtils.move failed" do
      FileUtils.stub!(:move).and_return(false)
      cbrain_local_data_provider.impl_provider_rename(userfile,"new_name").should be_false
    end
    
    it "should have change userfile name value" do
      cbrain_local_data_provider.impl_provider_rename(userfile,"new_name")
      userfile.name.should be == "new_name"
    end

    it "should return true if all works correctly" do
      FileUtils.stub!(:remove_entry)
      cbrain_local_data_provider.impl_provider_rename(userfile,"new_name").should be_true
    end 
  end

end
