
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
require 'pry-byebug'

describe FlatDirLocalDataProvider do
  let(:local_data_provider) {create(:flat_dir_local_data_provider)}
  let(:userfile) {create(:single_file, :data_provider => local_data_provider)}

  describe "#is_fast_syncing?" do

    it "should return true local data providers are considered fast syncing" do
      expect(local_data_provider.is_fast_syncing?).to be_truthy
    end
  end

  describe "#provider_full_path" do

    it "should call cache_full_path" do
      expect(local_data_provider).to receive(:cache_full_path).once
      local_data_provider.provider_full_path(userfile)
    end
  end

  describe "#impl_is_alive?" do

    it "should return true if remote_dir is a directory" do
      allow(File).to receive(:directory?).and_return(true)
      expect(local_data_provider.impl_is_alive?).to be_truthy
    end

    it "should return false if remote_dir is not a directory" do
      allow(File).to receive(:directory?).and_return(false)
      expect(local_data_provider.impl_is_alive?).to be_falsey
    end
  end

  describe "#impl_sync_to_cache" do

    it "should return true if all works correctly" do
      expect(local_data_provider).to be_truthy
    end
  end

  describe "#impl_sync_to_provider" do

    it "should return true if all works correctly" do
      expect(local_data_provider).to be_truthy
    end
  end

  describe "#provider_readhandle" do

    it "should call cache_readhandle" do
      expect(local_data_provider).to receive(:cache_readhandle).once
      local_data_provider.provider_readhandle(userfile)
    end
  end

  describe "#impl_provider_collection_index" do

    it "should call cache_collection_index" do
      expect(local_data_provider).to receive(:cache_collection_index).once
      local_data_provider.impl_provider_collection_index(userfile)
    end
  end
end

