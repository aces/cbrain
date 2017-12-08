
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

describe EnCbrainLocalDataProvider do
  let(:en_cbrain_local_data_provider) {create(:en_cbrain_local_data_provider, :remote_dir => "remote")}
  let(:userfile) {create(:single_file, :data_provider => en_cbrain_local_data_provider)}


  describe "#allow_file_owner_change?" do
    it "should always return true" do
      expect(en_cbrain_local_data_provider.allow_file_owner_change?).to be_truthy
    end
  end

  describe "#cache_prepare" do
     before(:each) do
      allow(SyncStatus).to receive(:ready_to_modify_cache).and_yield
    end

    it "should return true if all works correctly" do
      dp = en_cbrain_local_data_provider
      allow(Dir).to receive(:mkdir)
      expect(dp.cache_prepare(userfile)).to be_truthy
    end

    it "should call mkdir if new userdir not already a directory" do
      dp = en_cbrain_local_data_provider
      u = userfile
      allow(File).to receive(:directory?).and_return(false)
      expect(Dir).to receive(:mkdir).at_least(4)
      dp.cache_prepare(u)
    end

    it "should not call mkdir if new userdir is already a directory" do
      dp = en_cbrain_local_data_provider
      u = userfile
      allow(File).to receive(:directory?).and_return(true)
      expect(Dir).not_to receive(:mkdir)
      dp.cache_prepare(u)
    end
  end

  describe "#cache_full_path" do

    it "should return a Pathname containing full path" do
      cache_subdirs_from_name_values = ["146","22","92"]
      allow(en_cbrain_local_data_provider).to receive(:cache_subdirs_from_id).and_return(cache_subdirs_from_name_values)
      cache_full_path = Pathname.new("#{en_cbrain_local_data_provider.remote_dir}/#{cache_subdirs_from_name_values[0]}/#{cache_subdirs_from_name_values[1]}/#{cache_subdirs_from_name_values[2]}/#{userfile.name}")
      expect(en_cbrain_local_data_provider.cache_full_path(userfile)).to eq(cache_full_path)
    end
  end

  describe "#cache_erase" do

    it "should call SyncStatus.ready_to_modify_cache" do
      expect(SyncStatus).to receive(:ready_to_modify_cache).once
      en_cbrain_local_data_provider.cache_erase(userfile)
    end

    it "should return true if all works correctly" do
      allow(SyncStatus).to receive(:ready_to_modify_cache).and_yield
      expect(en_cbrain_local_data_provider.cache_erase(userfile)).to be_truthy
    end
  end

  describe "#impl_provider_erase" do

    it "should call FileUtils.remove_entry with cache_full_path and true" do
      expect(FileUtils).to receive(:remove_entry).once
      en_cbrain_local_data_provider.impl_provider_erase(userfile)
    end

    it "should return true if all works correctly" do
      allow(FileUtils).to receive(:remove_entry)
      expect(en_cbrain_local_data_provider.impl_provider_erase(userfile)).to be_truthy
    end
  end

  describe "#impl_provider_rename" do

    before(:each) do
      allow(userfile).to receive(:cache_full_path)
      allow(FileUtils).to receive(:move).and_return(true)
    end

    it "should return true if all works correctly" do
      allow(FileUtils).to receive(:remove_entry)
      expect(en_cbrain_local_data_provider.impl_provider_rename(userfile,"new_name")).to be_truthy
    end

    it "should return false if FileUtils.move failed" do
      allow(FileUtils).to receive(:move).and_return(false)
      expect(en_cbrain_local_data_provider.impl_provider_rename(userfile,"new_name")).to be_falsey
    end

  end

end

