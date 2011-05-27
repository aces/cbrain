#
# CBRAIN Project
#
# Tag spec
#
# Original author: Natacha Beck
#
# $Id$
#


require 'spec_helper'

describe Tag do
  before(:each) do 
    #objects required in tests below
    @tag = Factory.build(:tag)
    @tag.save
  end

  it "should create a new instance given valid attributes" do
    @tag.valid?.should be(true)
  end

  it "should not save without a name" do
    @tag.name = nil
    @tag.save.should  be(false)
  end

  it "should not save without a user_id" do
    @tag.user_id = nil
    @tag.save.should be(false)
  end

  it "should not save without a group_id" do
    @tag.group_id = nil
    @tag.save.should be(false)
  end

  it "should check that name is unique" do
    Factory.create(:tag, :group_id => "123", :name => "Abcdef")
    bad_name=Factory.build(:tag, :group_id => "123",:name => "Abcdef")
    bad_name.save.should be(false)
  end

  it "should check that name is unique only for same scope" do
    Factory.create(:tag, :group_id => "123", :name => "Abcdef")
    bad_name=Factory.build(:tag, :group_id => "124",:name => "Abcdef")
    bad_name.save.should be(true)
  end

  it "should check that name have specific format" do
    good_name = Factory.build(:tag, :name => "Abcdef")
    good_name.save.should be(true)
  end

  it "should check that name have specific format if not raise error" do
    bad_name = Factory.build(:tag, :name => "Ab@cdef")
    bad_name.save.should be(false)
  end

  it "should check tahe tag is belong to user" do
    bad_name = Factory.build(:tag, :name => "Ab@cdef")
    bad_name.save.should be(false)
  end

  it { should have_and_belong_to_many(:userfiles)}
  it { should belong_to(:user) }
  it { should belong_to(:group) }
  
end
