
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

describe IncomingVaultSshDataProvider do
  let(:incoming_vault_ssh_data_provider) {create(:incoming_vault_ssh_data_provider)}
  let(:user) {create(:normal_user)}

  describe "#is_browsable?" do

    it "should return true" do
      expect(incoming_vault_ssh_data_provider.is_browsable?).to be_truthy
    end

  end

  describe "#browse_remote_dir" do

    it "should return self.remote_dir + user.login if user is not nil" do
      allow(incoming_vault_ssh_data_provider).to receive(:remote_dir).and_return("remote_dir")
      path = "remote_dir" + "/#{user.login}"
      expect(incoming_vault_ssh_data_provider.browse_remote_dir(user)).to eq(path)
    end

    it "should return self.remote_dir if user is nil" do
      allow(incoming_vault_ssh_data_provider).to receive(:remote_dir).and_return("remote_dir")
      expect(incoming_vault_ssh_data_provider.browse_remote_dir(nil)).to eq("remote_dir")
    end

  end

  describe "allow_file_owner_change?" do

    it "should return false" do
      expect(incoming_vault_ssh_data_provider.allow_file_owner_change?).to be_falsey
    end

  end

end

