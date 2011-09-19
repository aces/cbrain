#
# CBRAIN Project
#
# CbrainMailer spec
#
# Original author: Natacha Beck
#
# $Id$
#

require 'spec_helper'

describe CbrainMailer do
  let(:user) {Factory.create(:user)}

  describe "#registration_confirmation" do
    
    it "should return if user is not an User" do
      user.stub(:is_a?).and_return(false)
      @email = CbrainMailer.registration_confirmation(user,"pwd").deliver
      @email.to.should be_nil
    end

    it "should call mail with :to => user.email" do
      user.stub(:is_a?).and_return(true)
      @email = CbrainMailer.registration_confirmation(user,"pwd").deliver
      @email.to.should include(user.email)
    end

  end

  describe "#forgotten_password" do

    it "should return if user is not an User" do
      user.stub(:is_a?).and_return(false)
      @email = CbrainMailer.forgotten_password(user).deliver
      @email.to.should be_nil
    end

    it "should call mail with :to => user.email" do
      user.stub(:is_a?).and_return(true)
      @email = CbrainMailer.forgotten_password(user).deliver
      @email.to.should include(user.email)
    end

  end

  describe "#cbrain_message" do

    it "should return true if user is blank" do
    @email = CbrainMailer.cbrain_message([]).deliver
    @email.to.should be_nil
    end

    it "should call mail with :to => [user].map(&:email)" do
      @email = CbrainMailer.cbrain_message([user]).deliver
      @email.to.to_a.should =~ [user].map(&:email)
    end
    
  end
  
end
