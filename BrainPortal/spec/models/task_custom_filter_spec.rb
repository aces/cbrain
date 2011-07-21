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
                                                   :created_at => "2011-04-04", :status => "New")
      @cbrain_task2 = Factory.create(:cbrain_task, :description => "desc2", :user_id => 2, :bourreau_id => 2,
                                                   :created_at => "2011-04-29", :status => "Completed")
    end
    
    it "should remove all non 'data['type']' task" do
      task1 = Factory.create("cbrain_task/diagnostics")
      task2 = Factory.create("cbrain_task/civet")
      filter.data = { "type" => "CbrainTask::Diagnostics" }
      filter.filter_scope(CbrainTask.scoped({})).should =~ [task1]
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
      it "should remove all task created before 'data['created_date_term']'" do
        filter.data = { "created_date_type" => 1, "created_date_term" => @cbrain_task2.created_at }
        filter.filter_scope(CbrainTask.scoped({})).should =~ [@cbrain_task1]
      end
    
      it "should remove all task created on 'data['created_date_term']'" do
        filter.data = { "created_date_type" => 0, "created_date_term" => @cbrain_task2.created_at }
        filter.filter_scope(CbrainTask.scoped({})).should =~ [@cbrain_task2]
      end
      
      it "should remove all task created after 'data['created_date_term']'" do
        filter.data = { "created_date_type" => 2, "created_date_term" => @cbrain_task1.created_at }
        filter.filter_scope(CbrainTask.scoped({})).should =~ [@cbrain_task2]
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
