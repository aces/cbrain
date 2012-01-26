
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

describe EnCbrainSshDataProvider do
  let(:en_cbrain_ssh_data_provider) {Factory.create(:en_cbrain_ssh_data_provider)}
  let(:userfile) {Factory.create(:userfile, :data_provider => en_cbrain_ssh_data_provider)}
  
  describe "#is_browsable?" do
    
    it "should return false" do
      en_cbrain_ssh_data_provider.is_browsable?.should be_false  
    end
    
  end

  describe "#allow_file_owner_change" do
    
    it "should return true" do
      en_cbrain_ssh_data_provider.allow_file_owner_change?.should be_true  
    end
    
  end

  describe "#impl_sync_to_provider" do
    
    it "should create directory" do
      en_cbrain_ssh_data_provider.stub!(:remote_dir).and_return("x/y/z")
      en_cbrain_ssh_data_provider.stub!(:ssh_shared_options)
      SshDataProvider.class_eval { def impl_sync_to_provider(userfile); end; }
      en_cbrain_ssh_data_provider.should_receive(:bash_this).with(/mkdir/)
      en_cbrain_ssh_data_provider.impl_sync_to_provider(userfile)
    end
    
  end

  describe "#impl_provider_erase" do

    it "should erase provider" do
      en_cbrain_ssh_data_provider.stub!(:remote_dir).and_return("x/y/z")
      en_cbrain_ssh_data_provider.stub!(:ssh_shared_options)
      en_cbrain_ssh_data_provider.should_receive(:bash_this).with(/rm -rf/)
      en_cbrain_ssh_data_provider.impl_provider_erase(userfile)
    end

    it "should return true" do
      en_cbrain_ssh_data_provider.stub!(:remote_dir).and_return("x/y/z")
      en_cbrain_ssh_data_provider.stub!(:ssh_shared_options)
      en_cbrain_ssh_data_provider.stub!(:bash_this)
      en_cbrain_ssh_data_provider.impl_provider_erase(userfile).should be_true
    end
  
  end

  describe "#impl_provider_rename" do
    before(:each) do
      path = Pathname.new("x/y/z")
      en_cbrain_ssh_data_provider.stub!(:provider_full_path).and_return(path)
    end

    it "should return false if file already exist" do
      sftp = mock('mock_sftp') 
      Net::SFTP.should_receive(:start).and_yield(sftp)
      req  = mock("req") 
      sftp.stub_chain(:lstat,:wait).and_return(req)
      req.stub_chain(:response, :ok?).and_return(true)
      en_cbrain_ssh_data_provider.impl_provider_rename(userfile,"new_name").should be_false
    end
    
    it "should return false if rename doesn't work" do
      sftp  = mock('mock_sftp') 
      Net::SFTP.should_receive(:start).and_yield(sftp)
      req1  = mock("req1") 
      sftp.stub_chain(:lstat,:wait).and_return(req1)
      req1.stub_chain(:response, :ok?).and_return(false)
      req2  = mock("req2") 
      sftp.stub_chain(:rename,:wait).and_return(req2)
      req2.stub_chain(:response, :ok?).and_return(false)
      en_cbrain_ssh_data_provider.impl_provider_rename(userfile,"new_name").should be_false
    end
    
    it "should return true if all works fine" do
      sftp  = mock('mock_sftp') 
      Net::SFTP.should_receive(:start).and_yield(sftp)
      req1  = mock("req1") 
      sftp.stub_chain(:lstat,:wait).and_return(req1)
      req1.stub_chain(:response, :ok?).and_return(false)
      req2  = mock("req2") 
      sftp.stub_chain(:rename,:wait).and_return(req2)
      req2.stub_chain(:response, :ok?).and_return(true)
      en_cbrain_ssh_data_provider.impl_provider_rename(userfile,"new_name").should be_true
    end
    
  end

  describe "#impl_provider_list_all" do
    
    it "should return a cbrain error" do
      lambda{en_cbrain_ssh_data_provider.impl_provider_list_all}.should raise_error(CbrainError)
    end
  
  end

  describe "#provider_full_path" do
    it "should return provider_full_path" do
      cache_subdirs_from_id = ["146","22","44"] 
      en_cbrain_ssh_data_provider.stub!(:cache_subdirs_from_id).and_return(cache_subdirs_from_id)
      en_cbrain_ssh_data_provider.stub!(:remote_dir).and_return("x/y/z")
      provider_full_path = 
        Pathname.new("#{en_cbrain_ssh_data_provider.remote_dir}/#{cache_subdirs_from_id[0]}/#{cache_subdirs_from_id[1]}/#{cache_subdirs_from_id[2]}/#{userfile.name}")
      en_cbrain_ssh_data_provider.provider_full_path(userfile).should be == provider_full_path
    end
  end
  
  
end

