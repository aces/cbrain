
#
# CBRAIN Project
#
# VaultSmartDataProvider Spec 
#
# Original author: Natacha Beck
#
# $Id$
#


require 'spec_helper'

describe VaultSmartDataProvider do
  let(:vault_smart_data_provider) {Factory.create(:vault_smart_data_provider)}
  
  describe "#after_initialize_select_provider" do
    
    it "should receive select_local_or_network_provider" do
      vault_smart_data_provider.should_receive(:select_local_or_network_provider)
      vault_smart_data_provider.after_initialize_select_provider
    end
    
  end
  
end
