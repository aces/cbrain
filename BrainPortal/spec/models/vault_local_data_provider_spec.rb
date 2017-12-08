
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

describe VaultLocalDataProvider do
  let(:vault_local_data_provider) {create(:vault_local_data_provider, :remote_dir => "remote")}
  let(:userfile) {create(:single_file, :data_provider => vault_local_data_provider)}

  describe "#cache_prepare" do

    before(:each) do
      allow(SyncStatus).to receive(:ready_to_modify_cache).and_yield
    end

    it "should return true if all works correctly" do
      allow(Dir).to receive(:mkdir)
      expect(vault_local_data_provider.cache_prepare(userfile)).to be_truthy
    end

    it "should call mkdir if new userdir not already a directory" do
      allow(File).to receive(:directory?).and_return(false)
      expect(Dir).to receive(:mkdir).once
      vault_local_data_provider.cache_prepare(userfile)
    end

    it "should not call mkdir if new userdir is already a directory" do
      allow(File).to receive(:directory?).and_return(true)
      expect(Dir).not_to receive(:mkdir)
      vault_local_data_provider.cache_prepare(userfile)
    end
  end

  describe "#cache_full_path" do

    it "should return a Pathname containing full path" do
      cache_full_path = Pathname.new("#{vault_local_data_provider.remote_dir}/#{userfile.user.login}/#{userfile.name}")
      expect(vault_local_data_provider.cache_full_path(userfile)).to eq(cache_full_path)
    end
  end

  describe "#cache_erase" do

    it "should call SyncStatus.ready_to_modify_cache" do
      expect(SyncStatus).to receive(:ready_to_modify_cache).once
      vault_local_data_provider.cache_erase(userfile)
    end

    it "should return true if all works correctly" do
      allow(SyncStatus).to receive(:ready_to_modify_cache).and_yield
      expect(vault_local_data_provider.cache_erase(userfile)).to be_truthy
    end
  end

  describe "#impl_provider_erase" do

    it "should call FileUtils.remove_entry" do
      expect(FileUtils).to receive(:remove_entry).once
      vault_local_data_provider.impl_provider_erase(userfile)
    end

    it "should return true if all works correctly" do
      allow(FileUtils).to receive(:remove_entry)
      expect(vault_local_data_provider.impl_provider_erase(userfile)).to be_truthy
    end
  end

  describe "#impl_provider_rename" do

    it "should call FileUtils.mv" do
      expect(FileUtils).to receive(:mv).once
      vault_local_data_provider.impl_provider_rename(userfile,"new_name")
    end

    it "should return true if all works correctly" do
      allow(FileUtils).to receive(:mv)
      expect(vault_local_data_provider.impl_provider_rename(userfile,"new_name")).to be_truthy
    end

    it "should return false if go in rescue" do
      allow(FileUtils).to receive(:mv).and_raise(ZeroDivisionError.new)
      expect(vault_local_data_provider.impl_provider_rename(userfile,"new_name")).to be_falsey
    end
  end
end

