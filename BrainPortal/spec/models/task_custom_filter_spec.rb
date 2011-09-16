#
# CBRAIN Project
#
# TaskCustomFilter spec
#
# Original author: Natacha Beck
#
# $Id$
#


require 'spec_helper'

describe TaskCustomFilter do
  let(:filter)  {Factory.create(:task_custom_filter)}
  
  describe "#filter_scope" do
    before(:each) do 
      @cbrain_task1 = Factory.create(:cbrain_task, :description => "desc1", :user_id => 1, :bourreau_id => 1,
                                                   :created_at => "2011-04-04", :status => "New",
                                                   :updated_at => "2011-05-04")
      @cbrain_task2 = Factory.create(:cbrain_task, :description => "desc2", :user_id => 2, :bourreau_id => 2,
                                                   :created_at => "2011-04-29", :status => "Completed",
                                                   :updated_at => "2011-05-29")
    end
    
    it "should remove all non 'data['type']' task with one type" do
      task1 = Factory.create("cbrain_task/diagnostics")
      task2 = Factory.create("cbrain_task/civet")
      filter.data = { "type" => "CbrainTask::Diagnostics" }
      filter.filter_scope(CbrainTask.scoped({})).should =~ [task1]
    end

    it "should remove all non 'data['type']' task with 2 types" do
      task1 = Factory.create("cbrain_task/diagnostics")
      task2 = Factory.create("cbrain_task/civet")
      filter.data = { "type" => ["CbrainTask::Diagnostics,CbrainTask::Civet"] }
      filter.filter_scope(CbrainTask.scoped({})).should =~ []
    end
    
    it "should remove all task without 'data['user_id']'" do
      filter.data = { "user_id" => @cbrain_task1.user_id }
      filter.filter_scope(CbrainTask.scoped({})).should =~ [@cbrain_task1]
    end
    
    it "should remove all task without 'data['bourreau_id']'" do
      filter.data = { "bourreau_id" => @cbrain_task1.bourreau_id }
      filter.filter_scope(CbrainTask.scoped({})).should =~ [@cbrain_task1]
    end
    
    it "should remove all task without 'data['status']'" do
      filter.data = { "status" => @cbrain_task1.status }
      filter.filter_scope(CbrainTask.scoped({})).should =~ [@cbrain_task1]
    end

    context "with date" do
      
      it "should only keep task created between 'data['abs_from'] and 'data['abs_to']'" do
        filter.data = { "date_attribute" => "created_at", "absolute_or_relative_from"=>"abs", "absolute_or_relative_to"=>"abs", "abs_from" => "04/04/2011", "abs_to" => "04/04/2011" }
        filter.filter_scope(CbrainTask.scoped({})).should =~ [@cbrain_task1]
      end
      
      it "should only keep task updates between 'data['abs_from'] and 'data['abs_to']'" do
        filter.data = { "date_attribute" => "updated_at", "absolute_or_relative_from"=>"abs", "absolute_or_relative_to"=>"abs", "abs_from" => "04/05/2011", "abs_to" => "04/05/2011" }
        filter.filter_scope(CbrainTask.scoped({})).should =~ [@cbrain_task1]
      end

      it "should only keep task created between 'data['abs_from'] and 'data['rel_date_to']'" do
        filter.data = { "date_attribute" => "created_at", "absolute_or_relative_from"=>"abs", "absolute_or_relative_to"=>"rel", "abs_from" => "29/04/2011", "rel_date_to" => "0" }
        filter.filter_scope(CbrainTask.scoped({})).should =~ [@cbrain_task2]
      end

      it "should only keep task updated between 'data['abs_from'] and 'data['rel_date_to']'" do
        filter.data = { "date_attribute" => "updated_at", "absolute_or_relative_from"=>"abs", "absolute_or_relative_to"=>"rel", "abs_from" => "29/05/2011", "rel_date_to" => "0" }
        filter.filter_scope(CbrainTask.scoped({})).should =~ [@cbrain_task2]
      end

      it "should only keep task updated last week" do
        filter.data = { "date_attribute" => "updated_at", "absolute_or_relative_from"=>"rel", "absolute_or_relative_to"=>"rel", "rel_date_from" => "#{1.week}", "rel_date_to" => "0" }
        @cbrain_task1.updated_at = Date.today - 1.day
        @cbrain_task1.save!
        filter.filter_scope(CbrainTask.scoped({})).should =~ [@cbrain_task1]
      end
      
    end

    context "with description scope" do
      it "should remove all task doesn't match with 'data['description_term']'" do
        filter.data = { "description_type" => "match", "description_term" => @cbrain_task1.description }
        filter.filter_scope(CbrainTask.scoped({})).should =~ [@cbrain_task1]
      end
    
      it "should remove all task doesn't begin with 'data['description_term']'" do
        filter.data = { "description_type" => "begin", "description_term" => @cbrain_task1.description[0..2] }
        filter.filter_scope(CbrainTask.scoped({})).should =~ [@cbrain_task1,@cbrain_task2]
      end
      
      it "should remove all task doesn't end with 'data['description_term']'" do
        filter.data = { "description_type" => "end", "description_term" => @cbrain_task1.description[-1].chr }
        filter.filter_scope(CbrainTask.scoped({})).should =~ [@cbrain_task1]
      end

      it "should remove all task doesn't contain 'data['description_term']'" do
        filter.data = { "description_type" => "contain", "description_term" => @cbrain_task1.description[1..3] }
        filter.filter_scope(CbrainTask.scoped({})).should =~ [@cbrain_task1,@cbrain_task2]
      end
    end
  end

  describe "#created_date_term" do                      
    it "should return nil if date_term is not defined" do
      filter.created_date_term.should be nil
    end
  end
  
  describe "#date_term=" do
    it "should assign the date_term in the data hash" do
      date = {"date_term(1i)"=>"2011", "date_term(2i)"=>"05", "date_term(3i)"=>"24"}
      filter.created_date_term=(date)
      filter.created_date_term.should == "#{date["created_date_term(1i)"]}-#{date["created_date_term(2i)"]}-#{date["created_date_term(3i)"]}"
    end
  end

end  
