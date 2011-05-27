#
# CBRAIN Project
#
# CustomFilter spec
#
# Original author: Natacha Beck
#
# $Id$
#


require 'spec_helper'

describe CustomFilter do
  let(:cf)  {Factory.create(:custom_filter)}
  
  describe "#filter_scope" do
    it "should raise an exception, this method should be redefined in subclasses" do
      lambda{cf.filter_scope(CustomFilter.scoped({}))}.should raise_error("Using filter_scope in CustomFilter base class. Should be used from a subclass.")
    end
  end

  describe "#filtered_class_controller" do
    it "should return the name of the controllerof the ressource being filtered (userfiles)" do
      ucf = Factory.create(:userfile_custom_filter)
      ucf.filtered_class_controller.should == "userfiles"
    end
    it "should return the name of the controllerof the ressource being filtered (tasks)" do
      tcf = Factory.create(:task_custom_filter)
      tcf.filtered_class_controller.should == "tasks"
    end
  end

  describe "#data" do
    it "should return an empty hash if no data was defined" do
      cf.data.should be_empty
    end
  end

  describe "#data=" do 
    it "should assign data hash to data" do
      data = {"key1" => "val1"}
      cf.data=(data)
      cf.data.should == {"key1" => "val1"}
    end
  end

end
