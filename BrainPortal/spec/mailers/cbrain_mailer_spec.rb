
#
# CBRAIN Project
#
# Copyright (C) 2008-2012
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

require 'rails_helper'

describe CbrainMailer do
  let(:user)   { create(:normal_user) }
  let(:portal) { double("portal",
                   :support_email        => 'support@example.com',
                   :system_from_email    => 'sysfrom@example.com',
                   :site_url_prefix      => 'fake://cbrain.site/',
                   :nh_support_email     => 'nh_support@example.com',
                   :nh_system_from_email => 'nh_sysfrom@example.com',
                   :nh_site_url_prefix   => 'nh_fake://cbrain.site/',
                 ).as_null_object
               }

  before(:each) do
    allow(RemoteResource).to receive(:current_resource).and_return(portal)
  end

  describe "#registration_confirmation" do

    it "should return if user is not an User" do
      allow(user).to receive(:is_a?).and_return(false)
      @email = CbrainMailer.registration_confirmation(user,"pwd").deliver
      expect(@email).to be_nil
    end

    it "should call mail with :to => user.email" do
      allow(user).to receive(:is_a?).and_return(true)
      @email = CbrainMailer.registration_confirmation(user,"pwd").deliver
      expect(@email.to).to include(user.email)
    end

  end

  describe "#forgotten_password" do

    it "should return if user is not an User" do
      allow(user).to receive(:is_a?).and_return(false)
      @email = CbrainMailer.forgotten_password(user).deliver
      expect(@email).to be_nil
    end

    it "should call mail with :to => user.email" do
      allow(user).to receive(:is_a?).and_return(true)
      @email = CbrainMailer.forgotten_password(user).deliver
      expect(@email.to).to include(user.email)
    end

  end

  describe "#general_message" do

    it "should return true if user is blank" do
      @email = CbrainMailer.general_message([]).deliver
      expect(@email).to be_nil
    end

    it "should call mail with :to => [user].map(&:email)" do
      @email = CbrainMailer.general_message([user]).deliver
      expect(@email.to.to_a).to match_array([user].map(&:email))
    end

  end

end

