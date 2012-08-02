
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

describe EnCbrainLocalDataProvider do
  let(:en_cbrain_local_data_provider) {Factory.create(:en_cbrain_local_data_provider, :remote_dir => "remote")}
  let(:userfile) {Factory.create(:userfile, :data_provider => en_cbrain_local_data_provider)}
  

  describe "#allow_file_owner_change?" do
    it "should always return true" do
      en_cbrain_local_data_provider.allow_file_owner_change?.should be_true
    end
  end

  describe "#cache_prepare" do
     before(:each) do
      SyncStatus.stub!(:ready_to_modify_cache).and_yield
    end

    it "should return true if all works correctly" do
      Dir.stub!(:mkdir)
      en_cbrain_local_data_provider.cache_prepare(userfile).should be_true
    end
    
    it "should call mkdir if new userdir not already a directory" do
      File.stub!(:directory?).and_return(false)
      Dir.should_receive(:mkdir).at_least(4)
      en_cbrain_local_data_provider.cache_prepare(userfile)
    end

    it "should not call mkdir if new userdir is already a directory" do
      File.stub!(:directory?).and_return(true)
      Dir.should_not_receive(:mkdir)
      en_cbrain_local_data_provider.cache_prepare(userfile)
    end
  end

  describe "#cache_full_path" do

    it "should return a Pathname containing full path" do
      cache_subdirs_from_name_values = ["146","22","92"] 
      en_cbrain_local_data_provider.stub!(:cache_subdirs_from_id).and_return(cache_subdirs_from_name_values)
      cache_full_path = Pathname.new("#{en_cbrain_local_data_provider.remote_dir}/#{cache_subdirs_from_name_values[0]}/#{cache_subdirs_from_name_values[1]}/#{cache_subdirs_from_name_values[2]}/#{userfile.name}")
      en_cbrain_local_data_provider.cache_full_path(userfile).should be == cache_full_path
    end
  end

  describe "#cache_erase" do
    
    it "should call SyncStatus.ready_to_modify_cache" do
      SyncStatus.should_receive(:ready_to_modify_cache).once
      en_cbrain_local_data_provider.cache_erase(userfile)
    end
    
    it "should return true if all works correctly" do
      SyncStatus.stub!(:ready_to_modify_cache).and_yield      
      en_cbrain_local_data_provider.cache_erase(userfile).should be_true
    end 
  end

  describe "#impl_provider_erase" do

    it "should call FileUtils.remove_entry with cache_full_path and true" do
      FileUtils.should_receive(:remove_entry).once
      en_cbrain_local_data_provider.impl_provider_erase(userfile)
    end
    
    it "should return true if all works correctly" do
      FileUtils.stub!(:remove_entry)
      en_cbrain_local_data_provider.impl_provider_erase(userfile).should be_true
    end
  end

  describe "#impl_provider_rename" do

    before(:each) do
      userfile.stub!(:cache_full_path)
      FileUtils.stub!(:move).and_return(true)
    end
    
    it "should return true if all works correctly" do
      FileUtils.stub!(:remove_entry)
      en_cbrain_local_data_provider.impl_provider_rename(userfile,"new_name").should be_true
    end 
    
    it "should return false if FileUtils.move failed" do
      FileUtils.stub!(:move).and_return(false)
      en_cbrain_local_data_provider.impl_provider_rename(userfile,"new_name").should be_false
    end

  end
  
end

