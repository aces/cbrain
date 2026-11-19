
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
# spec/models/background_activity/duplicate_task_spec.rb

require 'rails_helper'

RSpec.describe BackgroundActivity::DuplicateTask, type: :model do
  describe "#pretty_name" do
    # Setup the parent class method stub
    before do
      allow_any_instance_of(BackgroundActivity).to receive(:pretty_name).and_return("Duplicate Task")
    end

    context "when destination bourreau exists" do
      let(:options) { { dup_bourreau_id: 123 } }
      let(:activity) { described_class.new(options: options) }
      let(:bourreau) { instance_double(Bourreau, name: "Test Bourreau") }

      before do
        allow(Bourreau).to receive(:find_by_id).with(123).and_return(bourreau)
      end

      it "appends the bourreau name to the parent's pretty_name" do
        expect(activity.pretty_name).to eq("Duplicate Task to Test Bourreau")
      end
    end

    context "when destination bourreau is not found" do
      let(:options) { { dup_bourreau_id: 123 } }
      let(:activity) { described_class.new(options: options) }

      before do
        allow(Bourreau).to receive(:find_by_id).with(123).and_return(nil)
      end

      it "returns just the parent's pretty_name" do
        expect(activity.pretty_name).to eq("Duplicate Task")
      end
    end

    context "when dup_bourreau_id is nil" do
      let(:options) { { dup_bourreau_id: nil } }
      let(:activity) { described_class.new(options: options) }

      before do
        # We don't expect find_by_id to be called at all with nil
        # Or if it does, we need to allow it to be called with nil
        allow(Bourreau).to receive(:find_by_id).with(nil).and_return(nil)
      end

      it "returns just the parent's pretty_name" do
        expect(activity.pretty_name).to eq("Duplicate Task")
      end
    end

    context "when bourreau has no name (empty string)" do
      let(:options) { { dup_bourreau_id: 123 } }
      let(:activity) { described_class.new(options: options) }
      let(:bourreau) { instance_double(Bourreau, name: "") }

      before do
        allow(Bourreau).to receive(:find_by_id).with(123).and_return(bourreau)
      end

      it "returns just the parent's pretty_name" do
        expect(activity.pretty_name).to eq("Duplicate Task")
      end
    end
  end
end
