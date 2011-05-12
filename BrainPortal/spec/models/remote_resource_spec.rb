
#
# CBRAIN Project
#
# RemoteResource Spec 
#
# Original author: Nicolas Kassis
#
# $Id$
#


require 'spec_helper'

describe RemoteResource do
  before(:each) do
    @remote_resource = Factory.create(:remote_resource)
    @remote_resource.instance_eval do 
      alias  :live_remote_resource_info :remote_resource_info
      def remote_resource_info
        RemoteResourceInfo.dummy_record
      end
    end

  end
  
  it "should be valid with valid attributes" do
    @remote_resource.should be_valid
  end
  
  it "should have an invalid name for info.name after is_alive?" do
    @remote_resource.is_alive?
    @remote_resource.info.name.should == "???"
  end
  it "should set the time_of_death first time it detects down remote resource" do
    @remote_resource.is_alive?
    (@remote_resource.time_of_death-Time.now).should be < 1.minute
  end

  it "should set itself to offline if time_of_death is whithin last minute" do
    @remote_resource.update_attributes(:time_of_death  => 30.seconds.ago)
    @remote_resource.is_alive?
    @remote_resource.online.should be false
  end

  it "should reset the time_of_death flag if it's too old" do
    @remote_resource.update_attributes(:time_of_death  => 1.day.ago)
    @remote_resource.is_alive?
    (@remote_resource.time_of_death-Time.now).should be < 1.minute and @remote_resource.online.should be true
  end

  it "should be alive if @info.name is not ??? and time_of_death should be nil" do 
    @remote_resource.instance_eval do 
      def remote_resource_info
        info=RemoteResourceInfo.dummy_record
        info.name = "ABC"
        info
      end
    end
    @remote_resource.online = true
    @remote_resource.is_alive?.should be true and @remote_resource.time_of_death.should be nil
  end
end
