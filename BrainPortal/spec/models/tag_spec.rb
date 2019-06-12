
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

describe Tag do
  let (:user)   { create(:normal_user) }
  let (:group)  { create(:work_group) }
  let (:group2) { create(:work_group) }
  let (:tag)    { create(:tag, :user_id => user.id, :group_id => group.id) }

  it "should check that name is unique" do
    bad_name = build(:tag, :user_id => user.id, :group_id => tag.group_id, :name => tag.name)
    expect(bad_name).not_to be_valid
  end

  it "should check that name is unique only for same scope" do
    dup_name = build(:tag, :user_id => user.id, :group_id => group2.id, :name => tag.name)
    expect(dup_name).to be_valid
  end

  it "should check that name have specific format" do
    good_name = build(:tag, :user_id => user.id, :group_id => tag.group_id, :name => "Abcdef")
    expect(good_name).to be_valid
  end

  it "should not be valid if the name is invalid" do
    bad_name = build(:tag, :user_id => user.id, :group_id => tag.group_id, :name => "Ab@cdef")
    expect(bad_name).not_to be_valid
  end

end

