
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

describe "CbrainDeepClone" do

  let(:hash) { {:a => {:b => 1}} }

  describe "#cb_deep_clone" do
    it "should make a deep clone of the object" do
      h1 = hash.cb_deep_clone
      h1[:a][:b] = 2
      expect(hash[:a][:b]).to eq(1)
    end

  end
end