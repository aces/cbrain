
#
# CBRAIN Project
#
# CbrainSmartDataProvider Spec 
#
# Original author: Natacha Beck
#
# $Id$
#


require 'spec_helper'

describe CbrainSmartDataProvider do
  let(:cbrain_smart_data_provider) {Factory.create(:cbrain_smart_data_provider)}
  
  describe "#after_initialize_select_provider" do
    
    it "should receive select_local_or_network_provider" do
      cbrain_smart_data_provider.should_receive(:select_local_or_network_provider)
      cbrain_smart_data_provider.after_initialize_select_provider
    end
    
  end
  
end
