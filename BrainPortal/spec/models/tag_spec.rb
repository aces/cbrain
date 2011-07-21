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
  let (:tag) {Factory.create(:tag)}

  it "should check that name is unique" do
    bad_name=Factory.build(:tag, :group_id => tag.group_id, :name => tag.name)
    bad_name.should_not be_valid
  end

  it "should check that name is unique only for same scope" do
    bad_name=Factory.build(:tag, :name => tag.name)
    bad_name.should be_valid
  end

  it "should check that name have specific format" do
    good_name = Factory.build(:tag, :name => "Abcdef")
    good_name.should be_valid
  end

  it "should not be valid if the name is invalid" do
    bad_name = Factory.build(:tag, :name => "Ab@cdef")
    bad_name.should_not be_valid
  end

end
