
#
# CBRAIN Project
#
# Copyright (C) 2008-2020
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

describe FileInfo do
  let(:file_info) { FileInfo.new }

  describe "#depth" do
    it "should calculate the depth of the userfile" do
      file_info.name = "/x/y/z"
      expect(file_info.depth).to eq(3)
    end
    it "should raise an exception if no name is given" do
      file_info.name = ""
      expect{ file_info.depth }.to raise_error(CbrainError, "File doesn't have a name.")
    end
  end

end

