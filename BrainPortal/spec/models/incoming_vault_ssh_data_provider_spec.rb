
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

describe IncomingVaultSshDataProvider do
  let(:incoming_vault_ssh_data_provider) {Factory.create(:incoming_vault_ssh_data_provider)}
  let(:user) {Factory.create(:user)}
  
  describe "#is_browsable?" do
    
    it "should return true" do
      incoming_vault_ssh_data_provider.is_browsable?.should be_true
    end
    
  end

  describe "#browse_remote_dir" do

    it "should return self.remote_dir + user.login if user is not nil" do
      incoming_vault_ssh_data_provider.stub!(:remote_dir).and_return("remote_dir")
      path = "remote_dir" + "/#{user.login}"
      incoming_vault_ssh_data_provider.browse_remote_dir(user).should be == path 
    end

    it "should return self.remote_dir if user is nil" do
      incoming_vault_ssh_data_provider.stub!(:remote_dir).and_return("remote_dir")
      incoming_vault_ssh_data_provider.browse_remote_dir(nil).should be == "remote_dir"
    end
    
  end

  describe "allow_file_owner_change?" do

    it "should return false" do
      incoming_vault_ssh_data_provider.allow_file_owner_change?.should be_false
    end
  
  end
  
end

