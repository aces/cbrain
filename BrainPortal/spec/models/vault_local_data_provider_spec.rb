
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

describe VaultLocalDataProvider do
  let(:vault_local_data_provider) {Factory.create(:vault_local_data_provider, :remote_dir => "remote")}
  let(:userfile) {Factory.create(:userfile, :data_provider => vault_local_data_provider)}
  
  describe "#cache_prepare" do
    
    before(:each) do
      SyncStatus.stub!(:ready_to_modify_cache).and_yield      
    end
    
    it "should return true if all works correctly" do
      Dir.stub!(:mkdir)
      vault_local_data_provider.cache_prepare(userfile).should be_true
    end
    
    it "should call mkdir if new userdir not already a directory" do
      File.stub(:directory?).and_return(false)
      Dir.should_receive(:mkdir).once
      vault_local_data_provider.cache_prepare(userfile)
    end
    
    it "should not call mkdir if new userdir is already a directory" do
      File.stub(:directory?).and_return(true)
      Dir.should_not_receive(:mkdir)
      vault_local_data_provider.cache_prepare(userfile)
    end
  end

  describe "#cache_full_path" do

    it "should return a Pathname containing full path" do
      cache_full_path = Pathname.new("#{vault_local_data_provider.remote_dir}/#{userfile.user.login}/#{userfile.name}")
      vault_local_data_provider.cache_full_path(userfile).should be == cache_full_path
    end
  end

  describe "#cache_erase" do

    it "should call SyncStatus.ready_to_modify_cache" do
      SyncStatus.should_receive(:ready_to_modify_cache).once
      vault_local_data_provider.cache_erase(userfile)
    end
    
    it "should return true if all works correctly" do
      SyncStatus.stub!(:ready_to_modify_cache).and_yield      
      vault_local_data_provider.cache_erase(userfile).should be_true
    end 
  end

  describe "#impl_provider_erase" do
    
    it "should call FileUtils.remove_entry" do
      FileUtils.should_receive(:remove_entry).once
      vault_local_data_provider.impl_provider_erase(userfile)
    end
    
    it "should return true if all works correctly" do
      FileUtils.stub!(:remove_entry)
      vault_local_data_provider.impl_provider_erase(userfile).should be_true
    end
  end

  describe "#impl_provider_rename" do
    
    it "should call FileUtils.mv" do
      FileUtils.should_receive(:mv).once
      vault_local_data_provider.impl_provider_rename(userfile,"new_name")
    end 
    
    it "should return true if all works correctly" do
      FileUtils.stub!(:mv)
      vault_local_data_provider.impl_provider_rename(userfile,"new_name").should be_true
    end 
    
    it "should return false if go in rescue" do
      FileUtils.stub!(:mv).and_raise(ZeroDivisionError.new)
      vault_local_data_provider.impl_provider_rename(userfile,"new_name").should be_false
    end 
  end
end

