
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

describe TaskCustomFilter do
  let(:filter)  {create(:task_custom_filter)}
  let(:task_scope) { double("task_scope").as_null_object }

  let(:cbrain_task1) {
    create(:cbrain_task, :description => "desc1", :user_id => 1, :bourreau_id => 1,
                    :created_at => "2011-04-04", :status => "New",
                    :updated_at => "2011-05-04")
  }

  let(:cbrain_task2) {
    create(:cbrain_task, :description => "desc2", :user_id => 2, :bourreau_id => 2,
                    :created_at => "2011-04-29", :status => "Completed",
                    :updated_at => "2011-05-29")
  }

  describe "#filter_scope" do
    it "should scope type if type filter given" do
      filter.data = { "type" => "CbrainTask::Diagnostics" }
      expect(filter).to receive(:scope_type).and_return(task_scope)
      filter.filter_scope(task_scope)
    end

    it "should not scope type if type filter not given" do
      expect(filter).not_to receive(:scope_type)
      filter.filter_scope(task_scope)
    end

    it "should remove all task without 'data['user_id']'" do
      filter.data = { "user_id" => cbrain_task1.user_id }
      expect(filter.filter_scope(CbrainTask.where(nil))).to match_array([cbrain_task1])
    end

    it "should remove all task without 'data['bourreau_id']'" do
      filter.data = { "bourreau_id" => cbrain_task1.bourreau_id }
      expect(filter.filter_scope(CbrainTask.where(nil))).to match_array([cbrain_task1])
    end

    it "should remove all task without 'data['status']'" do
      filter.data = { "status" => cbrain_task1.status }
      expect(filter.filter_scope(CbrainTask.where(nil))).to match_array([cbrain_task1])
    end

    context "with date" do

      it "should only keep task created between 'data['absolute_from'] and 'data['absolute_to']'" do
        filter.data = { "date_attribute" => "created_at", "absolute_or_relative_from"=>"absolute", "absolute_or_relative_to"=>"absolute", "absolute_from" => "04/04/2011", "absolute_to" => "04/04/2011" }
        expect(filter.filter_scope(CbrainTask.where(nil))).to match_array([cbrain_task1])
      end

      it "should only keep task updates between 'data['absolute_from'] and 'data['absolute_to']'" do
        filter.data = { "date_attribute" => "updated_at", "absolute_or_relative_from"=>"absolute", "absolute_or_relative_to"=>"absolute", "absolute_from" => "04/05/2011", "absolute_to" => "04/05/2011" }
        expect(filter.filter_scope(CbrainTask.where(nil))).to match_array([cbrain_task1])
      end

      it "should only keep task created between 'data['absolute_from'] and 'data['relative_date_to']'" do
        filter.data = { "date_attribute" => "created_at", "absolute_or_relative_from"=>"absolute", "absolute_or_relative_to"=>"relative", "absolute_from" => "29/04/2011", "relative_to" => "0" }
        expect(filter.filter_scope(CbrainTask.where(nil))).to match_array([cbrain_task2])
      end

      it "should only keep task updated between 'data['absolute_from'] and 'data['relative_date_to']'" do
        filter.data = { "date_attribute" => "updated_at", "absolute_or_relative_from"=>"absolute", "absolute_or_relative_to"=>"relative", "absolute_from" => "29/05/2011", "relative_to" => "0" }
        expect(filter.filter_scope(CbrainTask.where(nil))).to match_array([cbrain_task2])
      end

      it "should only keep task updated last week" do
        filter.data = { "date_attribute" => "updated_at", "absolute_or_relative_from"=>"relative", "absolute_or_relative_to"=>"relative", "relative_from" => "#{1.week}", "relative_to" => "0" }
        cbrain_task1.updated_at = Date.today - 1.day
        cbrain_task1.save!
        expect(filter.filter_scope(CbrainTask.where(nil))).to match_array([cbrain_task1])
      end

    end

    context "with description scope" do
      it "should remove all task doesn't match with 'data['description_term']'" do
        filter.data = { "description_type" => "match", "description_term" => cbrain_task1.description }
        expect(filter.filter_scope(CbrainTask.where(nil))).to match_array([cbrain_task1])
      end

      it "should remove all task doesn't begin with 'data['description_term']'" do
        filter.data = { "description_type" => "begin", "description_term" => cbrain_task1.description[0..2] }
        expect(filter.filter_scope(CbrainTask.where(nil))).to match_array([cbrain_task1,cbrain_task2])
      end

      it "should remove all task doesn't end with 'data['description_term']'" do
        filter.data = { "description_type" => "end", "description_term" => cbrain_task1.description[-1].chr }
        expect(filter.filter_scope(CbrainTask.where(nil))).to match_array([cbrain_task1])
      end

      it "should remove all task doesn't contain 'data['description_term']'" do
        filter.data = { "description_type" => "contain", "description_term" => cbrain_task1.description[1..3] }
        expect(filter.filter_scope(CbrainTask.where(nil))).to match_array([cbrain_task1,cbrain_task2])
      end
    end
  end

  describe "#created_date_term" do
    it "should return nil if date_term is not defined" do
      expect(filter.created_date_term).to be nil
    end
  end

  describe "#date_term=" do
    it "should assign the date_term in the data hash" do
      date = {"date_term(1i)"=>"2011", "date_term(2i)"=>"05", "date_term(3i)"=>"24"}
      filter.created_date_term=(date)
      expect(filter.created_date_term).to eq("#{date["created_date_term(1i)"]}-#{date["created_date_term(2i)"]}-#{date["created_date_term(3i)"]}")
    end
  end

end

