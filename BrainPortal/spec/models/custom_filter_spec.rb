
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

describe CustomFilter do
  let(:cf)  {create(:custom_filter)}

  describe "#filter_scope" do
    it "should raise an exception, this method should be redefined in subclasses" do
      expect{cf.filter_scope(CustomFilter.where(nil))}.to raise_error("Using filter_scope in CustomFilter base class. Should be used from a subclass.")
    end
  end

  describe "#filtered_class_controller" do
    it "should return the name of the controllerof the ressource being filtered (userfiles)" do
      ucf = create(:userfile_custom_filter)
      expect(ucf.filtered_class_controller).to eq("userfiles")
    end
    it "should return the name of the controllerof the ressource being filtered (tasks)" do
      tcf = create(:task_custom_filter)
      expect(tcf.filtered_class_controller).to eq("tasks")
    end
  end

  describe "#data" do
    it "should return an empty hash if no data was defined" do
      expect(cf.data).to be_empty
    end
  end

  describe "#data=" do
    it "should assign data hash to data" do
      data = {"key1" => "val1"}
      cf.data=(data)
      expect(cf.data).to eq({"key1" => "val1"})
    end
  end

end

