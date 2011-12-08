require 'spec_helper'

describe RemoteResourceInfo do
  describe "#dummy_record" do
    it "should create a record where all values are '???'" do
      rri = RemoteResourceInfo.dummy_record
      rri[:id].should == 0
      rri.keys.each do |k|
        rri[k].should == '???' if k != :id && k != :bourreau_cms_rev
      end
    end
  end
  describe "#mock_record" do
    it "should create a record where all values are set to the argument given" do
      mock_value = "abc"
      rri = RemoteResourceInfo.mock_record(mock_value)
      rri[:id].should == 0
      rri.keys.each do |k|
        rri[k].should == mock_value if k != :id && k != :bourreau_cms_rev
      end
    end
  end
  describe "#[]" do
    it "should return the value associatied with the key if set" do
      rri = RemoteResourceInfo.new
      rri[:host_name] = "value"
      rri[:host_name].should == "value"
    end
    it "should return '???' if no value set for given key" do
      rri = RemoteResourceInfo.new
      rri[:host_name].should == '???'
    end
  end
end

