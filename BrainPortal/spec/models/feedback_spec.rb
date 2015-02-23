
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

describe Feedback do
  before(:each) do 
    #objects required in tests below
    @feedback = Factory.build(:feedback)
    @feedback.save
  end

  it "should create a new instance given valid attributes" do
    expect(@feedback.valid?).to be(true)
  end
  
  it "should be associate with user" do
    expect(Feedback.reflect_on_association(:user)).not_to be_nil
  end
  
  it "should not save without a summary" do
    @feedback.summary = nil
    expect(@feedback.save).to be(false) 
  end
  
  it "should not save without a details" do
    @feedback.details = nil
    expect(@feedback.save).to be(false) 
  end

  it "should not save without a blank summary" do
    @feedback.summary = ""
    expect(@feedback.save).to be(false) 
  end
  
  it "should not save without a blank details" do
    @feedback.details = ""
    expect(@feedback.save).to be(false) 
  end
  
end

