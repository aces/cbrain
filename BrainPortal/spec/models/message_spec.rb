
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

describe Message do
  let(:user)  { create(:normal_user) }

  describe "#send_message" do

    it "should not send a new message if new message is a pure repeat of an existing one" do
      Message.send_message(user, {:message_type => "notice", :header => "Task completed", :variable_text => "var1",
                                  :description => "desc", :read => false, :critical => false}).inspect
      expect do
        Message.send_message(user, {:message_type => "notice", :header => "Task completed", :variable_text => "var1",
                                    :description => "desc", :read => false, :critical => false}).inspect
      end.to change{ Message.count }.by(0)
    end

    it "should send a new message if Message is empty" do
      expect do
        Message.send_message(user, {:message_type => "notice", :header => "Task completed", :variable_text => "var1",
                                    :description => "desc", :read => false, :critical => false}).inspect
      end.to change{ Message.count }.by(1)
    end

    it "should not send a new message if same message already exist and var_text is not empty (just concat variable_text)" do
      Message.send_message(user, {:message_type => "notice", :header => "Task completed", :variable_text => "var2",
                                  :description => "desc", :read => false, :critical => false}).inspect
      expect do
        Message.send_message(user, {:message_type => "notice", :header => "Task completed", :variable_text => "var3",
                                    :description => "desc", :read => false, :critical => false}).inspect
      end.to change{ Message.count }.by(0)
    end

    it "should create a new message if we add a new_record" do
      Message.send_message(user, {:message_type => "notice", :header => "Task completed", :variable_text => "var2",
                                  :description => "desc", :read => false, :critical => false}).inspect
      expect do
        Message.send_message(user, {:message_type => "notice", :header => "New task completed", :variable_text => "var3",
                                    :description => "desc", :read => false, :critical => false}).inspect
      end.to change{ Message.count }.by(1)
    end

  end

  describe "#send_me_to" do

    it "should send a message starting with an object" do
      mess1 = create(:message)
      expect do
        mess1.send_me_to(user)
      end.to change{ Message.count }.by(1)
    end
  end

  describe "#forward_to_group" do
    let(:user2) {create(:normal_user)}
    let(:mess1) {create(:message)}

    it "should not send message if destination user already have the message" do
      mess1.send_me_to(user)
      expect do
         mess1.forward_to_group(user)
      end.to change{ Message.count }.by(0)
    end

    it "should send message if destination user doesn't have this message" do
      mess1.send_me_to(user)
      expect do
         mess1.forward_to_group(user2)
      end.to change{ Message.count }.by(1)
    end
  end

  describe "#send_internal_error_message" do


    it "send a message to all users and admin (only admin)" do
      expect do
        exception = Exception.new("error")
        allow(exception).to receive(:backtrace).and_return([""])
        allow(WorkGroup).to receive(:find_by_id).and_return(User.all_admins.map(&:own_group).uniq.compact)
        Message.send_internal_error_message("","head", exception)
      end.to change { Message.count }.by(User.all_admins.count)
    end

    it "send a message to all users and admin (admin + normal user)" do
      users  = [user]
      expect do
        exception = Exception.new("error")
        allow(exception).to receive(:backtrace).and_return([""])
        allow(WorkGroup).to receive(:find_by_id).and_return(User.all_admins.map(&:own_group).uniq.compact)
        Message.send_internal_error_message(users,"head", exception)
      end.to change { Message.count }.by(User.all_admins.count + users.size)
    end

  end

  describe "#append_variable_text" do
    let(:mess1) {create(:message, :variable_text => "var1")}
    it "should format the text_var prefixing with timestamp" do
      expect(mess1.send_me_to(user)[0].variable_text).to match(
        /^\[\d{4}\-\d{2}\-\d{2}\s+\d{2}\:\d{2}\:\d{2}\s+UTC\]\s+#{mess1.variable_text}\n$/
      )
    end
  end
end

