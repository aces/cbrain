
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

describe Site do
  before(:each) do
    @site         = create(:site)
    @site_manager = create(:site_manager, :site => @site)
    @site_user    = create(:normal_user, :site => @site)
    @site.save
  end

  it "should save with valid attributes" do
    expect(@site.save).to be(true)
  end

  it "should not save without a name" do
    @site.name = nil
    expect(@site.save).to  be(false)
  end

  it "should return the array of managers whened asked" do
    expect(@site.managers).to eq([@site_manager])
  end

  it "should set new managers on save" do
    @site_user.type = "SiteManager"
    @site_user.save
    @site.reload
    expect(@site.managers.map(&:id)).to include(@site_user.id)
  end

end

