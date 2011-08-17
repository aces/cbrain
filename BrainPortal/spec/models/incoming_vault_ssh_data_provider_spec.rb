
#
# CBRAIN Project
#
# IncomingVaultSshDataProvider Spec 
#
# Original author: Natacha Beck
#
# $Id$
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
