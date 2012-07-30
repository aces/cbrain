
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

describe ActiveRecordLog do
  
  let(:ar_object) { Factory.create(:tag) }
  
  describe "#active_record_object" do
    it "should return nil if the class given is invalid" do
      arl = ActiveRecordLog.create(:ar_id  => ar_object.id, :ar_class => "XYZ")
      arl.active_record_object.should be_nil
    end
    it "should return nil if the class is not an ActiveRecord subclass" do
      arl = ActiveRecordLog.create(:ar_id  => ar_object.id, :ar_class => "String")
      arl.active_record_object.should be_nil
    end
    it "should return nil if no id is given" do
      arl = ActiveRecordLog.create(:ar_class => ar_object.class.to_s)
      arl.active_record_object.should be_nil
    end
    it "should return the associated ActiveRecord object" do
      arl = ActiveRecordLog.create(:ar_id  => ar_object.id, :ar_table_name => ar_object.class.table_name.to_s)
      arl.active_record_object.should == ar_object
    end
  end
end

