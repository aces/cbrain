
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

describe UserfileCustomFilter do
  let(:filter)     { create(:userfile_custom_filter) }
  let(:task_scope) { double("task_scope").as_null_object }

  let(:userfile1)  { create(:single_file, :name => "file_1", :created_at => "2011-04-04", :updated_at => "2011-05-04", :size => 1779) }
  let(:userfile2)  { create(:single_file, :name => "file_2", :created_at => "2011-04-29", :updated_at => "2011-05-29", :size => 2558) }

  describe "#filter_scope" do

    it "should remove all task without 'data['user_id']'" do
      filter.data = { "user_id" => userfile1.user_id }
      expect(filter.filter_scope(Userfile.where(nil)).map(&:id)).to match_array([userfile1.id])
    end

    it "should remove all task without 'data['group_id']'" do
      filter.data = { "group_id" => userfile1.group_id }
      expect(filter.filter_scope(Userfile.where(nil)).map(&:id)).to match_array([userfile1.id])
    end

    it "should remove all task without 'data['data_provider_id']'" do
      filter.data = { "data_provider_id" => userfile1.data_provider_id }
      expect(filter.filter_scope(Userfile.where(nil)).map(&:id)).to match_array([userfile1.id])
    end

    it "should remove all non 'data['type']' userfile" do
      u1 = create(:text_file)
           create(:single_file)
      filter.data = { "type" => u1.class.to_s }
      expect(filter.filter_scope(Userfile.where(nil))).to match_array([u1])
    end

    context "with date" do

      it "should only keep userfile created between 'data['absolute_from'] and 'data['absolute_to']'" do
        userfile1
        filter.data = { "date_attribute" => "created_at", "absolute_or_relative_from"=>"absolute", "absolute_or_relative_to"=>"absolute", "absolute_from" => "04/04/2011", "absolute_to" => "04/04/2011" }
        expect(filter.filter_scope(Userfile.where(nil)).map(&:id)).to match_array([userfile1.id])
      end

      it "should only keep task updates between 'data['absolute_from'] and 'data['absolute_to']'" do
        userfile1
        filter.data = { "date_attribute" => "updated_at", "absolute_or_relative_from"=>"absolute", "absolute_or_relative_to"=>"absolute", "absolute_from" => "04/05/2011", "absolute_to" => "04/05/2011" }
        expect(filter.filter_scope(Userfile.where(nil)).map(&:id)).to match_array([userfile1.id])
      end

      it "should only keep task created between 'data['absolute_from'] and 'data['relative_date_to']'" do
        userfile2
        filter.data = { "date_attribute" => "created_at", "absolute_or_relative_from"=>"absolute", "absolute_or_relative_to"=>"relative", "absolute_from" => "29/04/2011", "relative_date_to" => "0" }
        expect(filter.filter_scope(Userfile.where(nil)).map(&:id)).to match_array([userfile2.id])
      end

      it "should only keep task updated between 'data['absolute_from'] and 'data['relative_date_to']'" do
        userfile2
        filter.data = { "date_attribute" => "updated_at", "absolute_or_relative_from"=>"absolute", "absolute_or_relative_to"=>"relative", "absolute_from" => "29/05/2011", "relative_date_to" => "0" }
        expect(filter.filter_scope(Userfile.where(nil)).map(&:id)).to match_array([userfile2.id])
      end

      it "should only keep task updated last week" do
        filter.data = { "date_attribute" => "updated_at", "absolute_or_relative_from"=>"relative", "absolute_or_relative_to"=>"relative", "relative_from" => "#{1.week}", "relative_to" => "0" }
        userfile1.updated_at = Date.today - 1.day
        userfile1.save!
        expect(filter.filter_scope(Userfile.where(nil)).map(&:id)).to match_array([userfile1.id])
      end

    end

    context "with size" do
      before(:each) { userfile1; userfile2 }
      it "should remove all userfile with size lower than 'data['size_term']'" do
        filter.data = { "size_type" => "1", "size_term" => (userfile2.size.to_f/1000) }
        expect(filter.filter_scope(Userfile.where(nil)).map(&:id)).to match_array([userfile1.id])
      end

      it "should remove all userfile with size equal 'data['size_term']'" do
        filter.data = { "size_type" => "0", "size_term" => (userfile2.size.to_f/1000) }
        expect(filter.filter_scope(Userfile.where(nil)).map(&:id)).to match_array([userfile2.id])
      end

      it "should remove all userfile with size greater than 'data['size_term']'" do
        filter.data = { "size_type" => "2", "size_term" => (userfile1.size.to_f/1000) }
        expect(filter.filter_scope(Userfile.where(nil)).map(&:id)).to match_array([userfile2.id])
      end
    end

    context "with name scope" do
      before(:each) { userfile1; userfile2 }
      it "should remove all userfile doesn't match with 'data['file_name_term']'" do
        filter.data = { "file_name_type" => "match", "file_name_term" => userfile1.name }
        expect(filter.filter_scope(Userfile.where(nil)).map(&:id)).to match_array([userfile1.id])
      end

      it "should remove all userfile doesn't begin with 'data['file_name_term']'" do
        filter.data = { "file_name_type" => "begin", "file_name_term" => userfile1.name[0..2] }
        expect(filter.filter_scope(Userfile.where(nil)).map(&:id)).to match_array([userfile1.id,userfile2.id])
      end

      it "should remove all userfile doesn't end with 'data['file_name_term']'" do
        filter.data = { "file_name_type" => "end", "file_name_term" => userfile1.name[-1].chr }
        expect(filter.filter_scope(Userfile.where(nil)).map(&:id)).to match_array([userfile1.id])
      end

      it "should remove all userfile doesn't contain 'data['file_name_term']'" do
        filter.data = { "file_name_type" => "contain", "file_name_term" => userfile1.name[1..3] }
        expect(filter.filter_scope(Userfile.where(nil)).map(&:id)).to match_array([userfile1.id,userfile2.id])
      end
    end
  end

  context "tag management" do
    let(:tag1) {create(:tag)}
    let(:tag2) {create(:tag)}

    describe "#tag_ids=" do
      it "should assign tags to the data hash" do
        filter.tag_ids=( [tag1.id.to_i] )
        expect(filter.tag_ids).to match_array([tag1.id.to_s])
      end
    end

    describe "#tags" do

      it "should return empty array if no tags is used" do
        filter.data = nil
        expect(filter.tag_ids).to be_empty
      end
      it "should return only the tags in the data hash" do
        filter.data = { "tag_ids" => [tag1.id,tag2.id]}
        expect(filter.tag_ids).to match_array([tag1.id,tag2.id])
      end
    end
  end

  describe "#date_term=" do
    it "should assign the date_term in the data hash" do
      date = {"date_term(1i)"=>"2011", "date_term(2i)"=>"05", "date_term(3i)"=>"24"}
      filter.date_term=(date)
      expect(filter.date_term).to eq("#{date["date_term(1i)"]}-#{date["date_term(2i)"]}-#{date["date_term(3i)"]}")
    end
  end


  describe "#date_term" do
    it "should return nil if date_term is not defined" do
      expect(filter.date_term).to be nil
    end
  end

end

