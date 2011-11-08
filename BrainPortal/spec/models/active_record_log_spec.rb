require 'spec_helper'

describe ActiveRecordLog do
  
  let(:ar_object) { Factory.create(:tag) }
  
  describe "#active_record_object" do
    it "should return nil if the class given is invalid" do
      arl = ActiveRecordLog.create(:ar_id  => ar_object.id, :ar_class => "XYZ")
      arl.active_record_object.should be_nil
    end
    it "should return nil if the class is not an ActiveRecord subclass" do
      arl = ActiveRecordLog.create(:ar_id  => ar_object.id, :ar_class => "String")
      arl.active_record_object.should be_nil
    end
    it "should return nil if no id is given" do
      arl = ActiveRecordLog.create(:ar_class => ar_object.class.to_s)
      arl.active_record_object.should be_nil
    end
    it "should return the associated ActiveRecord object" do
      arl = ActiveRecordLog.create(:ar_id  => ar_object.id, :ar_class => ar_object.class.to_s)
      arl.active_record_object.should == ar_object
    end
  end
end