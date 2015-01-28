
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

require 'spec_helper'

describe SingleFile do
  let(:single_file) { Factory.create(:single_file)}
  let(:file_entry)  { double("file_entry", :size => 1024).as_null_object}
        
  before(:each) do
    allow(single_file).to receive(:list_files).and_return([file_entry])
  end
  
  describe "#set_size!" do
    
    it "should set size to addition of file_entry.size" do
      single_file.set_size
      single_file.reload
      expect(single_file.size).to eq(1024)
    end
  end
  
end               

