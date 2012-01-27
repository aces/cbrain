
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

describe Tag do
  let (:tag) {Factory.create(:tag)}

  it "should check that name is unique" do
    bad_name=Factory.build(:tag, :group_id => tag.group_id, :name => tag.name)
    bad_name.should_not be_valid
  end

  it "should check that name is unique only for same scope" do
    bad_name=Factory.build(:tag, :name => tag.name)
    bad_name.should be_valid
  end

  it "should check that name have specific format" do
    good_name = Factory.build(:tag, :name => "Abcdef")
    good_name.should be_valid
  end

  it "should not be valid if the name is invalid" do
    bad_name = Factory.build(:tag, :name => "Ab@cdef")
    bad_name.should_not be_valid
  end

end

