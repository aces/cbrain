require 'spec_helper'

describe Group do
  let(:group) {Factory.create(:system_group)}

  describe "#default_creator" do
    it "should set creator to admin if not set" do
      admin_user_id = User.admin.id
      new_group = Factory.create(:system_group, :creator_id => nil)
      new_group.creator_id.should == admin_user_id
    end
    it "should  set creator to admin even if already set" do
      admin_user_id = User.admin.id
      new_user_id = Factory.create(:user).id
      new_group = Factory.create(:system_group, :creator_id => new_user_id)
      new_group.creator_id.should == admin_user_id
    end
  end
end
