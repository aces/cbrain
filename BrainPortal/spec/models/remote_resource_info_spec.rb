
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

describe RemoteResourceInfo do
  describe "#dummy_record" do
    it "should create a record where all values are '???'" do
      rri = RemoteResourceInfo.dummy_record
      expect(rri[:id]).to eq(0)
      rri.keys.each do |k|
        expect(rri[k]).to eq('???') if k != "id" && k != "bourreau_cms_rev"
      end
    end
  end
  describe "#mock_record" do
    it "should create a record where all values are set to the argument given" do
      mock_value = "abc"
      rri = RemoteResourceInfo.mock_record(mock_value)
      expect(rri[:id]).to eq(0)
      rri.keys.each do |k|
        expect(rri[k]).to eq(mock_value) if k != "id" && k != "bourreau_cms_rev"
      end
    end
  end
  describe "#[]" do
    it "should return the value associatied with the key if set" do
      rri = RemoteResourceInfo.new
      rri[:host_name] = "value"
      expect(rri[:host_name]).to eq("value")
    end
    it "should return '???' if no value set for given key" do
      rri = RemoteResourceInfo.new
      expect(rri[:host_name]).to eq('???')
    end
  end
end

