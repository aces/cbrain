
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

describe CbrainSshDataProvider do
  let(:cbrain_ssh_data_provider) {Factory.create(:cbrain_ssh_data_provider)}
  let(:userfile) {Factory.create(:userfile, :data_provider => cbrain_ssh_data_provider)}
  
  describe "#is_browsable?" do
    
    it "should return false" do
      cbrain_ssh_data_provider.is_browsable?.should be_false  
    end
    
  end

  describe "#impl_sync_to_provider" do
    
    it "should create directory" do
      cbrain_ssh_data_provider.stub!(:remote_dir).and_return("x/y/z")
      cbrain_ssh_data_provider.stub!(:ssh_shared_options)
      SshDataProvider.class_eval { def impl_sync_to_provider(userfile); end; }
      cbrain_ssh_data_provider.should_receive(:remote_bash_this).with(/mkdir/)
      cbrain_ssh_data_provider.impl_sync_to_provider(userfile)
    end
    
  end

  describe "#impl_provider_erase" do

    it "should erase provider" do
      cbrain_ssh_data_provider.stub!(:remote_dir).and_return("x/y/z")
      cbrain_ssh_data_provider.stub!(:ssh_shared_options)
      cbrain_ssh_data_provider.should_receive(:remote_bash_this).with(/rm -rf/)
      cbrain_ssh_data_provider.impl_provider_erase(userfile)
    end

    it "should return true" do
      cbrain_ssh_data_provider.stub!(:remote_dir).and_return("x/y/z")
      cbrain_ssh_data_provider.stub!(:ssh_shared_options)
      cbrain_ssh_data_provider.stub!(:remote_bash_this)
      cbrain_ssh_data_provider.impl_provider_erase(userfile).should be_true
    end
  
  end

  describe "#impl_provider_rename" do
    before(:each) do
      path = Pathname.new("x/y/z")
      cbrain_ssh_data_provider.stub!(:provider_full_path).and_return(path)
      cache_subdirs_from_name = ["146","22"] 
      cbrain_ssh_data_provider.stub!(:cache_subdirs_from_name).and_return(cache_subdirs_from_name)
      cbrain_ssh_data_provider.stub!(:remote_dir).and_return("x/y/z")
    end

    it "should return false if file already exist" do
      sftp = mock('mock_sftp')
      sftp.stub!(:mkdir!)
      Net::SFTP.should_receive(:start).and_yield(sftp)
      req  = mock("req") 
      sftp.stub_chain(:lstat,:wait).and_return(req)
      req.stub_chain(:response, :ok?).and_return(true)
      cbrain_ssh_data_provider.impl_provider_rename(userfile,"new_name").should be_false
    end
    
    it "should return false if rename doesn't work" do
      sftp = mock('mock_sftp') 
      Net::SFTP.should_receive(:start).and_yield(sftp)
      sftp.stub!(:mkdir!)
      req1  = mock("req1") 
      sftp.stub_chain(:lstat,:wait).and_return(req1)
      req1.stub_chain(:response, :ok?).and_return(false)
      req2  = mock("req2") 
      sftp.stub_chain(:rename,:wait).and_return(req2)
      req2.stub_chain(:response, :ok?).and_return(false)
      cbrain_ssh_data_provider.impl_provider_rename(userfile,"new_name").should be_false
    end
    
    it "should return true if all works fine" do
      sftp = mock('mock_sftp') 
      Net::SFTP.should_receive(:start).and_yield(sftp)
      sftp.stub!(:mkdir!)
      req1  = mock("req1") 
      sftp.stub_chain(:lstat,:wait).and_return(req1)
      req1.stub_chain(:response, :ok?).and_return(false)
      req2  = mock("req2") 
      sftp.stub_chain(:rename,:wait).and_return(req2)
      req2.stub_chain(:response, :ok?).and_return(true)
      cbrain_ssh_data_provider.impl_provider_rename(userfile,"new_name").should be_true
    end
    
  end

  describe "#impl_provider_list_all" do
    
    it "should return a cbrain error" do
      lambda{cbrain_ssh_data_provider.impl_provider_list_all}.should raise_error(CbrainError)
    end
  
  end

  describe "#provider_full_path" do
    it "should return provider_full_path" do
      cache_subdirs_from_name = ["146","22"] 
      cbrain_ssh_data_provider.stub!(:cache_subdirs_from_name).and_return(cache_subdirs_from_name)
      cbrain_ssh_data_provider.stub!(:remote_dir).and_return("x/y/z")
      provider_full_path = 
        Pathname.new("#{cbrain_ssh_data_provider.remote_dir}/#{userfile.user.login}/#{cache_subdirs_from_name[0]}/#{cache_subdirs_from_name[1]}/#{userfile.name}")
      cbrain_ssh_data_provider.provider_full_path(userfile).should be == provider_full_path
    end
  end
  
end

