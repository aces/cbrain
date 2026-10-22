
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

  let(:user1)     { create(:normal_user) }
  let(:user2)     { create(:normal_user) }
  let(:bourreau1) { create(:bourreau) }
  let(:bourreau2) { create(:bourreau) }

  let(:cbrain_task1) {
    t=create(:cbrain_task, :description => "desc1", :user_id => user1.id, :bourreau_id => bourreau1.id,
                    :created_at => "2011-01-04", :status => "New",
                    :updated_at => "2011-02-04")
    t.update(:created_at => DateTime.parse("2011-01-04 12:00:00"), # stupidly, create() no longer sets those
             :updated_at => DateTime.parse("2011-02-04 12:00:00"))
    t
  }

  let(:cbrain_task2) {
    t=create(:cbrain_task, :description => "desc2", :user_id => user2.id, :bourreau_id => bourreau2.id,
                    :created_at => "2012-01-04", :status => "Completed",
                    :updated_at => "2012-02-04")
    t.update(:created_at => DateTime.parse("2012-01-04 12:00:00"),
             :updated_at => DateTime.parse("2012-02-04 12:00:00"))
    t
  }

  describe "#filter_scope" do
    it "should scope type if type filter given" do
      filter.data = { :types => [ "CbrainTask::Diagnostics" ] }
      expect(filter).to receive(:scope_types).and_return(task_scope)
      filter.filter_scope(task_scope)
    end

    it "should not scope type if type filter not given" do
      expect(filter).not_to receive(:scope_types)
      filter.filter_scope(task_scope)
    end

    it "should filter tasks by user_ids" do
      t1=cbrain_task1
      t2=cbrain_task2
      filter.data = { :user_ids => [ t1.user_id.to_s ] }
      expect(filter.filter_scope(CbrainTask.where(nil))).to match_array([t1])
    end

    it "should filter tasks by bourreau_ids" do
      t1=cbrain_task1
      t2=cbrain_task2
      filter.data = { :bourreau_ids => [ t1.bourreau_id.to_s ] }
      expect(filter.filter_scope(CbrainTask.where(nil))).to match_array([t1])
    end

    it "should filter tasks by status" do
      t1=cbrain_task1
      t2=cbrain_task2
      filter.data = { :status => [ t1.status ] }
      expect(filter.filter_scope(CbrainTask.where(nil))).to match_array([t1])
    end

    context "with date" do

      it "should only keep task created between 'data[:absolute_from] and 'data[:absolute_to]'" do
        t1=cbrain_task1
        t2=cbrain_task2
        filter.data = { :date_attribute => "created_at", :absolute_or_relative_from=>"absolute", :absolute_or_relative_to=>"absolute", :absolute_from => "2011-01-03", :absolute_to => "2011-01-05" }
        expect(filter.filter_scope(CbrainTask.where(nil))).to match_array([t1])
      end

      it "should only keep task updated between 'data[:absolute_from] and 'data[:absolute_to]'" do
        t1=cbrain_task1
        t2=cbrain_task2
        filter.data = { :date_attribute => "updated_at", :absolute_or_relative_from=>"absolute", :absolute_or_relative_to=>"absolute", :absolute_from => "2011-02-03", :absolute_to => "2011-02-05" }
        expect(filter.filter_scope(CbrainTask.where(nil))).to match_array([t1])
      end

      it "should only keep task created between 'data[:absolute_from] and 'data[:relative_to]'" do
        t1=cbrain_task1
        t2=cbrain_task2
        filter.data = { :date_attribute => "created_at", :absolute_or_relative_from=>"absolute", :absolute_or_relative_to=>"relative", :absolute_from => "2012-01-03", :relative_to => "0" }
        expect(filter.filter_scope(CbrainTask.where(nil))).to match_array([t2])
      end

      it "should only keep task updated between 'data[:absolute_from] and 'data[:relative_to]'" do
        t1=cbrain_task1
        t2=cbrain_task2
        filter.data = { :date_attribute => "updated_at", :absolute_or_relative_from=>"absolute", :absolute_or_relative_to=>"relative", :absolute_from => "2012-02-03", :relative_to => "0" }
        expect(filter.filter_scope(CbrainTask.where(nil))).to match_array([t2])
      end

      it "should only keep task updated last week" do
        t1=cbrain_task1
        t2=cbrain_task2
        filter.data = { :date_attribute => "updated_at", :absolute_or_relative_from=>"relative", :absolute_or_relative_to=>"relative", :relative_from => "#{1.week.to_i}", :relative_to => "0" }
        t1.updated_at = Date.today - 1.day
        t1.save!
        expect(filter.filter_scope(CbrainTask.where(nil))).to match_array([t1])
      end

    end

    context "with description scope" do
      it "should remove all task doesn't match with 'data[:description_term]'" do
        filter.data = { :description_type => "match", :description_term => cbrain_task1.description }
        expect(filter.filter_scope(CbrainTask.where(nil))).to match_array([cbrain_task1])
      end

      it "should remove all task doesn't begin with 'data[:description_term]'" do
        filter.data = { :description_type => "begin", :description_term => cbrain_task1.description[0..2] }
        expect(filter.filter_scope(CbrainTask.where(nil))).to match_array([cbrain_task1,cbrain_task2])
      end

      it "should remove all task doesn't end with 'data[:description_term]'" do
        filter.data = { :description_type => "end", :description_term => cbrain_task1.description[-1].chr }
        expect(filter.filter_scope(CbrainTask.where(nil))).to match_array([cbrain_task1])
      end

      it "should remove all task doesn't contain 'data[:description_term]'" do
        filter.data = { :description_type => "contain", :description_term => cbrain_task1.description[1..3] }
        expect(filter.filter_scope(CbrainTask.where(nil))).to match_array([cbrain_task1,cbrain_task2])
      end
    end
  end

end

