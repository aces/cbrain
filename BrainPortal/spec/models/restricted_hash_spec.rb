require 'spec_helper'

describe RestrictedHash do
  
  let(:restricted_hash) do
    RestrictedHash(:key1, :key2).merge(
      :key1 => "value1",
      :key2 => "value2"
    )
  end
  let(:restricted_hash_class) {restricted_hash.class}
  
  describe "Class Methods" do
    describe "#allowed_keys" do
      it "should list valid keys" do
        restricted_hash_class.allowed_keys.should =~ [:key1, :key2]
      end
      it "should allow me to modify the allowed keys" do
        restricted_hash_class.allowed_keys :key3, :key4
        restricted_hash_class.allowed_keys.should =~ [:key3, :key4]
      end
    end
    describe "#allowed_keys=" do
      it "should allow me to modify the allowed keys" do
        restricted_hash_class.allowed_keys =  [:key5, :key6]
        restricted_hash_class.allowed_keys.should =~ [:key5, :key6]
      end
    end
    describe "#key_is_allowed?" do
      it "should return true for an allowed key" do
        restricted_hash_class.key_is_allowed?(:key1).should be_true
      end
      it "should return nil for a disallowed key" do
        restricted_hash_class.key_is_allowed?(:key3).should be_nil
      end
    end
    
  end
  
  describe "#[]" do
    it "should allow me to access a valid key" do
      restricted_hash[:key1].should == "value1"
    end
    
    it "should raise an exception if I try to access an invalid key" do
      lambda{restricted_hash[:key3]}.should raise_error(CbrainError, "Illegal attribute '#{:key3}'.")
    end
  end
 
  describe "#[]=" do
    it "should allow me to assign to a valid key" do
      restricted_hash[:key1] = "value1a"
      restricted_hash[:key1].should == "value1a"
    end

    it "should raise an exception if I try to assign to an invalid key" do
      lambda{restricted_hash[:key3] = "value3"}.should raise_error(CbrainError, "Illegal attribute '#{:key3}'.")
    end
  end
  
  describe "#allowed_keys" do
    it "should list valid keys" do
      restricted_hash.allowed_keys.should =~ [:key1, :key2]
    end
  end
  
  describe "#key_is_allowed?" do
    it "should return true for an allowed key" do
      restricted_hash.key_is_allowed?(:key1).should be_true
    end
    it "should return nil for a disallowed key" do
      restricted_hash.key_is_allowed?(:key3).should be_nil
    end
  end
  
  describe "#merge" do
    it "should merge with a hash with valid keys" do
      new_hash = restricted_hash.merge(:key1 => "value1a")
      new_hash[:key1].should == "value1a"
    end
  
    it "should not merge with a hash with invalid keys" do
      lambda { restricted_hash.merge(:key3 => "value3") }.should raise_error(CbrainError, "Illegal attribute '#{:key3}'.") 
    end
  end
  
  describe "#merge!" do
    it "should merge with a hash with valid keys" do
      restricted_hash.merge!(:key1 => "value1a")
      restricted_hash[:key1].should == "value1a"
    end
  
    it "should not merge with a hash with invalid keys" do
      lambda { restricted_hash.merge!(:key3 => "value3") }.should raise_error(CbrainError, "Illegal attribute '#{:key3}'.") 
    end
  end
  
  describe "method-style access" do
    it "should allow me to access a valid key" do
      restricted_hash.key1.should == "value1"
    end
    it "should raise an exception if I try to access an invalid key" do
      lambda{restricted_hash.key3}.should raise_error(CbrainError, "Illegal attribute '#{:key3}'.")
    end
     it "should allow me to assign to a valid key" do
      restricted_hash.key1 = "value1a"
      restricted_hash.key1.should == "value1a"
    end

    it "should raise an exception if I try to assign to an invalid key" do
      lambda{restricted_hash.key3 = "value3"}.should raise_error(CbrainError, "Illegal attribute '#{:key3}'.")
    end
  end
  
end