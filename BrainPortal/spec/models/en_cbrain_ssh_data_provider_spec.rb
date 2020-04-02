
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

describe EnCbrainSshDataProvider do
  let(:en_cbrain_ssh_data_provider) {create(:en_cbrain_ssh_data_provider)}
  let(:userfile) {create(:single_file, :data_provider => en_cbrain_ssh_data_provider)}

  describe "#is_browsable?" do

    it "should return false" do
      expect(en_cbrain_ssh_data_provider.is_browsable?).to be_falsey
    end

  end

  describe "#allow_file_owner_change" do

    it "should return true" do
      expect(en_cbrain_ssh_data_provider.allow_file_owner_change?).to be_truthy
    end

  end


  describe "#impl_provider_erase" do

    it "should erase provider" do
      allow(en_cbrain_ssh_data_provider).to receive(:remote_dir).and_return("x/y/z")
      allow(en_cbrain_ssh_data_provider).to receive(:ssh_shared_options)
      expect(en_cbrain_ssh_data_provider).to receive(:remote_bash_this).with(/rm -rf/, any_args)
      en_cbrain_ssh_data_provider.impl_provider_erase(userfile)
    end

    it "should return true" do
      allow(en_cbrain_ssh_data_provider).to receive(:remote_dir).and_return("x/y/z")
      allow(en_cbrain_ssh_data_provider).to receive(:ssh_shared_options)
      allow(en_cbrain_ssh_data_provider).to receive(:remote_bash_this)
      expect(en_cbrain_ssh_data_provider.impl_provider_erase(userfile)).to be_truthy
    end

  end

  describe "#impl_provider_rename" do
    before(:each) do
      path = Pathname.new("x/y/z")
      allow(en_cbrain_ssh_data_provider).to receive(:provider_full_path).and_return(path)
    end

    it "should attempt to unlock the CBRAIN SSH agent" do
      expect(en_cbrain_ssh_data_provider).to receive(:master)
      expect(Net::SFTP).to receive(:start).and_return "OK"
      expect(en_cbrain_ssh_data_provider.impl_provider_rename(userfile,"new_name")).to eq("OK")
    end

    it "should return false if file already exist" do
      sftp = double('mock_sftp')
      expect(Net::SFTP).to receive(:start).and_yield(sftp)
      req  = double("req")
      allow(sftp).to receive_message_chain(:lstat,:wait).and_return(req)
      allow(req).to receive_message_chain(:response, :ok?).and_return(true)
      expect(en_cbrain_ssh_data_provider).to receive(:master) # just ignore it
      expect(en_cbrain_ssh_data_provider.impl_provider_rename(userfile,"new_name")).to be_falsey
    end

    it "should return false if rename doesn't work" do
      sftp  = double('mock_sftp')
      expect(Net::SFTP).to receive(:start).and_yield(sftp)
      req1  = double("req1")
      allow(sftp).to receive_message_chain(:lstat,:wait).and_return(req1)
      allow(req1).to receive_message_chain(:response, :ok?).and_return(false)
      req2  = double("req2")
      allow(sftp).to receive_message_chain(:rename,:wait).and_return(req2)
      allow(req2).to receive_message_chain(:response, :ok?).and_return(false)
      expect(en_cbrain_ssh_data_provider).to receive(:master) # just ignore it
      expect(en_cbrain_ssh_data_provider.impl_provider_rename(userfile,"new_name")).to be_falsey
    end

    it "should return true if all works fine" do
      sftp  = double('mock_sftp')
      expect(Net::SFTP).to receive(:start).and_yield(sftp)
      req1  = double("req1")
      allow(sftp).to receive_message_chain(:lstat,:wait).and_return(req1)
      allow(req1).to receive_message_chain(:response, :ok?).and_return(false)
      req2  = double("req2")
      allow(sftp).to receive_message_chain(:rename,:wait).and_return(req2)
      allow(req2).to receive_message_chain(:response, :ok?).and_return(true)
      expect(en_cbrain_ssh_data_provider).to receive(:master) # just ignore it
      expect(en_cbrain_ssh_data_provider.impl_provider_rename(userfile,"new_name")).to be_truthy
    end

  end

  describe "#impl_provider_list_all" do

    it "should return a cbrain error" do
      expect{en_cbrain_ssh_data_provider.impl_provider_list_all}.to raise_error(CbrainError)
    end

  end

  describe "#provider_full_path" do
    it "should return provider_full_path" do
      cache_subdirs_from_id = ["146","22","44"]
      allow(en_cbrain_ssh_data_provider).to receive(:cache_subdirs_from_id).and_return(cache_subdirs_from_id)
      allow(en_cbrain_ssh_data_provider).to receive(:remote_dir).and_return("x/y/z")
      provider_full_path =
        Pathname.new("#{en_cbrain_ssh_data_provider.remote_dir}/#{cache_subdirs_from_id[0]}/#{cache_subdirs_from_id[1]}/#{cache_subdirs_from_id[2]}/#{userfile.name}")
      expect(en_cbrain_ssh_data_provider.provider_full_path(userfile)).to eq(provider_full_path)
    end
  end


end

