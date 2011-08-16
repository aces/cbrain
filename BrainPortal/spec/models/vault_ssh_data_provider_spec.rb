
#
# CBRAIN Project
#
# VaultSshDataProvider Spec 
#
# Original author: Natacha Beck
#
# $Id$
#


require 'spec_helper'

describe VaultSshDataProvider do
  let(:vault_ssh_data_provider) {Factory.create(:vault_ssh_data_provider)}
  let(:userfile) {Factory.create(:userfile, :data_provider => vault_ssh_data_provider)}
  
  describe "#is_browsable?" do
    
    it "should return false" do
      vault_ssh_data_provider.is_browsable?.should be_false  
    end
    
  end

  describe "#impl_sync_to_provider" do
    
    it "should create directory" do
      vault_ssh_data_provider.stub!(:remote_dir).and_return("x/y/z")
      vault_ssh_data_provider.stub!(:ssh_shared_options)
      SshDataProvider.class_eval { def impl_sync_to_provider(userfile); end; }
      vault_ssh_data_provider.should_receive(:bash_this).with(/mkdir/)
      vault_ssh_data_provider.impl_sync_to_provider(userfile)
    end
    
  end

  describe "#impl_provider_list_all" do
    
    it "should return a cbrain error if isn't browsable" do
      vault_ssh_data_provider.stub!(:is_browsable?).and_return(false)
      lambda{vault_ssh_data_provider.impl_provider_list_all}.should raise_error(CbrainError)
    end

    it "should not return a cbrain error if is browsable" do
      vault_ssh_data_provider.stub!(:is_browsable?).and_return(true)
      lambda{vault_ssh_data_provider.impl_provider_list_all}.should_not raise_error(CbrainError)
    end
  
  end

  describe "#provider_full_path" do
    it "should return provider_full_path" do
      vault_ssh_data_provider.stub!(:remote_dir).and_return("x/y/z")
      provider_full_path = 
        Pathname.new("#{vault_ssh_data_provider.remote_dir}/#{userfile.user.login}/#{userfile.name}")
      vault_ssh_data_provider.provider_full_path(userfile).should be == provider_full_path
    end
  end
  
  
end
