
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

RSpec.describe ActiveRecordLog, :type => :model do

  let(:ar_object) { create(:tag) }

  describe "#active_record_object" do
    it "should return nil if the class given is invalid" do
      arl = ActiveRecordLog.create(:ar_id  => ar_object.id, :ar_table_name => "XYZ")
      expect(arl.active_record_object).to be_nil
    end
    it "should return nil if the class is not an ActiveRecord subclass" do
      arl = ActiveRecordLog.create(:ar_id  => ar_object.id, :ar_table_name => "String")
      expect(arl.active_record_object).to be_nil
    end
    it "should return nil if no id is given" do
      arl = ActiveRecordLog.create(:ar_table_name => ar_object.class.to_s)
      expect(arl.active_record_object).to be_nil
    end
    it "should return the associated ActiveRecord object" do
      arl = ActiveRecordLog.create(:ar_id  => ar_object.id, :ar_table_name => ar_object.class.table_name.to_s)
      expect(arl.active_record_object).to eq(ar_object)
    end
  end
end

