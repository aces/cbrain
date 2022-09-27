
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

# This test file is meant to test stuff that are particular to
# being in a Github CI testing environment.
describe "GithubCI" do

  describe "environment" do

    # This code allows us to FAIL a test for sure
    # if the CBRAIN_FAILTEST is set to something other
    # than blank, or the string 'false'.
    it "should fail this test if CBRAIN_FAILTEST is set" do
      envvar = ENV["CBRAIN_FAILTEST"].presence
      envvar = nil if envvar =~ /^false$/i # a particular string value we can use too
      expect(envvar).to be_falsey
    end

  end

end
