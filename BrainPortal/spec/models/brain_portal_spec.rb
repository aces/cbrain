#
# CBRAIN Project
#
# BrainPortal spec
#
# Original author: Natacha Beck
#
# $Id$
#


require 'spec_helper'

describe BrainPortal do
  let(:current_bp) {Factory.create(:brain_portal)}

  describe "#lock" do
    it "should be locked after lock was called" do
      current_bp.portal_locked = false
      current_bp.lock!
      current_bp.portal_locked.should be true
    end
  end

  describe "#unlock" do 
    it "should be unlocked after unlock was called" do
      current_bp.portal_locked = true
      current_bp.unlock!
      current_bp.portal_locked.should be false
    end
  end
  
end
