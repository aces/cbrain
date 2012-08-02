
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

describe CbrainTask do
  let!(:cb_civet) {Factory.create("cbrain_task/civet")}

  context "Utility Methods" do 
  
    describe "name" do 
      
      it "should return a simple name for task" do
        cb_civet.name.should be == "Civet"
      end 
   
    end
  
  
    
    describe "name_and_bourreau" do 

      it "should return name@bourreau with (Unknown) if no bourreau is know" do
        cb_civet.stub_chain(:bourreau, :name).and_raise(StandardError)
        cb_civet.name_and_bourreau.should be == "#{cb_civet.name}@(Unknown)"
      end

      it "should return name@bourreau" do
        bourreau = cb_civet.bourreau.name
        cb_civet.name_and_bourreau.should be == "#{cb_civet.name}@#{bourreau}"
      end
      
    end
  
  
    
    describe "fullname" do 

      it "should return name@MyBourreau/id if task have id" do
        bourreau = cb_civet.bourreau.name
        result = "#{cb_civet.name}@#{bourreau}/#{cb_civet.id}"
        cb_civet.fullname.should be == result
      end

      it "should return name@MyBourreau/(NoId) if task have no id" do
        bourreau = cb_civet.bourreau.name
        cb_civet.id = nil 
        result = "#{cb_civet.name}@#{bourreau}/(NoId)"
        cb_civet.fullname.should be == result
      end
      
    end
  
  
    
    describe "pretty_name" do 

      it "should return name" do
        cb_civet.pretty_name.should be == cb_civet.name
      end
      
    end
  
  
    
    describe "self.pretty_name" do 

      it "should return a simple name for task" do
        CbrainTask.pretty_name.should be == "Cbrain Task"
      end
      
    end
  
  
    
    describe "self.tool" do 

      it "should call where on Tool" do 
        Tool.should_receive(:where).and_return([1])
        CbrainTask.tool
      end
    
    end
  
  
    
    describe "tool" do 

      it "should call class and tool on self" do
        my_class = double("class")
        cb_civet.stub!(:class).and_return(my_class)
        my_class.should_receive(:tool).and_return("tools")
        cb_civet.tool
      end
      
    end
  
  
    
    describe "self.pseudo_sort_columns" do 

      it "should return [\"batch\"]" do
        CbrainTask.pseudo_sort_columns.should be == ["batch"]
      end
      
    end
  
  
    
    describe "to_xml" do 
      
      it "should start with '<?xml'" do
        cb_civet.to_xml.should =~ /^<\?xml/ 
      end

      it "should end with '</subclass>'" do
        cb_civet.to_xml.should =~ /\/civet>$/ 
      end 
    
    end
  
  
    
    describe "full_cluster_workdir" do 
      
      it "should not called cluster_shared_dir if cluster_workdir is blank" do 
        cb_civet.stub!(:cluster_workdir).and_return(nil)
        cb_civet.should_not_receive(:cluster_shared_dir)
        cb_civet.full_cluster_workdir
      end

      it "should called cluster_shared_dir in other case" do
        cb_civet.stub!(:cluster_workdir).and_return("val")
        cb_civet.should_receive(:cluster_shared_dir).and_return("path")
        cb_civet.full_cluster_workdir.should be == "path/val"
      end
      
    end
  
  
    
    describe "cluster_shared_dir" do 
      
      it "should raise an error if task have no bourreau" do
        cb_civet.stub!(:bourreau).and_return(nil)
        lambda{cb_civet.cluster_shared_dir}.should raise_error
      end

      it "should raise an error if cluster shared directory not defined for Bourreau" do
        mybourreau = double("mybourreau")
        cb_civet.stub!(:bourreau).and_return(mybourreau)
        mybourreau.stub!(:cms_shared_dir).and_return("")
        lambda{cb_civet.cluster_shared_dir}.should raise_error
      end

      it  "should return shared directory in other case" do
        mybourreau = double("mybourreau")
        cb_civet.stub!(:bourreau).and_return(mybourreau)
        shared_dir = double("shared")
        mybourreau.stub!(:cms_shared_dir).and_return(shared_dir)
        cb_civet.cluster_shared_dir.should be == shared_dir
      end
      
    end
  
    
    describe "short_description" do 

      it "should raise an error if we only have a new line" do
        cb_civet.stub!(:description).and_return("\n")
        lambda{cb_civet.short_description}.should raise_error
      end

      it "should return only the last line" do
        cb_civet.stub!(:description).and_return("first line\nsecond line")
        cb_civet.short_description.should be == "first line"
      end
      
    end

  end


  
  context "Useful ID Generators" do 
  
    describe "bname_tid" do #OK
      
      it "should return a string '?/?'" do
        cb_civet.bourreau.name = nil 
        cb_civet.id = nil
        cb_civet.bname_tid.should be == "?/?"
      end

      it "should return a string 'bname/?'" do
        cb_civet.id = nil
        cb_civet.bname_tid.should be == "#{cb_civet.bourreau.name}/?"
      end
      
      it "should return a string '?/tid'" do
        cb_civet.bourreau.name = nil 
        cb_civet.bname_tid.should be == "?/#{cb_civet.id}"
      end
      
      
      it "should return a string 'bname/tid'" do
        cb_civet.bname_tid.should be == "#{cb_civet.bourreau.name}/#{cb_civet.id}" 
      end
    
    end
  
  
    
    describe "bname_tid_dashed" do
      
      it "should return a string 'Unk-Unk'" do
        cb_civet.bourreau.name = nil 
        cb_civet.id = nil
        cb_civet.bname_tid_dashed.should be == "Unk-Unk"
      end

      it "should return a string 'bname-Unk'" do
        cb_civet.id = nil
        cb_civet.bname_tid_dashed.should be == "#{cb_civet.bourreau.name}-Unk"
      end
      
      it "should return a string 'Unk-tid'" do
        cb_civet.bourreau.name = nil 
        cb_civet.bname_tid_dashed.should be == "Unk-#{cb_civet.id}"
      end
      
      
      it "should return a string 'bname-tid'" do
        cb_civet.bname_tid_dashed.should be == "#{cb_civet.bourreau.name}-#{cb_civet.id}" 
      end
      
    end

  end

  
  
  context "Run Number ID Methods"
  
    describe "run_number" do
    
      it "should return 1 if is nil" do
        cb_civet.run_number = nil 
        cb_civet.run_number.should be == 1
      end

      it "should return run_number value if is not nil" do
        cb_civet.run_number = 2
        cb_civet.run_number.should be == 2
      end
    
    end
  
  
    
    describe "run_id" do 

      it "should return a string 'task_id-run_number' where run_number is an arg" do
        arg    = 3
        result = "#{cb_civet.id}-#{arg}"
        cb_civet.run_id(arg).should be == result
      end

      it "should return a string 'task_id-run_number where run_number is self.run_number'" do
        run_number = 5
        result = "#{cb_civet.id}-#{run_number}"
        cb_civet.stub!(:run_number).and_return(run_number)
        cb_civet.run_id.should be == result
      end

  end


  
  describe "log_params_changes" do #PB

    it "should changed value if params have same key with different value" do
      cb_civet.log_params_changes({:key1 => "val1"},{:key1 => "val2"})
      cb_civet.getlog.should =~ /Changed key \:key1\, old=\"val1\"\, new=\"val2\"/
    end

    it "should can't compare value if params have same key and data is not comparable" do
      class M < String
        def ==(other)
          return true if other.size == self.size
        end
      end
      
      val1 = M.new
      val2 = Exception.new("error")
      
      cb_civet.log_params_changes({:key1 => val1},{:key1 => val2})
      cb_civet.getlog.should  =~ /Uncomparable key :key1, old=#{val1.inspect}, new=#{val2.inspect}/
    end
         
    it "should deleted key if new_params have no more the key" do
      cb_civet.log_params_changes({:key1 => "val1"},{})
      cb_civet.getlog.should =~ /Deleted key :key1 with value \"val1\"/
    end

    it "should added key if new_params have new key" do
      cb_civet.log_params_changes({},{:key1 => "val1"})
      cb_civet.getlog.should =~ /Added key :key1 with value \"val1\"/
    end

    it "should add 'Total of' in log if numchange > 0" do
      cb_civet.log_params_changes({:key1 => "val1"},{:key1 => "val2"})
      cb_civet.getlog.should =~ /Total of 1 changes observed./
    end

    it "should add 'No changes' if !(numchange > 0)  " do
      cb_civet.log_params_changes({:key1 => "val1"},{:key1 => "val1"})
      cb_civet.getlog.should =~ /No changes to params observed./
    end
  
  end


  
  describe "add_prerequisites" do
    let!(:cb_civet_other) {Factory.create("cbrain_task/civet")}
    
    it "should return an error if 'for_what' isn't ':for_setup' or ':for_post_processing'" do
      lambda{cb_civet.add_prerequisites("for_what", cb_civet_other)}.should raise_error("Prerequisite argument 'for_what' must be :for_setup or :for_post_processing")
    end

    it "should return an error if needed state is not allowed" do
      lambda{cb_civet.add_prerequisites(:for_setup, cb_civet_other,"not_allowed")}.should raise_error("Prerequisite argument needed_state='not_allowed' is not allowed.")
    end

    it "should return error if other_task id is blank" do
      cb_civet_other.id = ""
      lambda{cb_civet.add_prerequisites(:for_setup, cb_civet_other,"-")}.should raise_error("Cannot add a prerequisite based on a task that has no ID yet!")
    end

    it "should return error if self.id == otask_id" do
      cb_civet.id = cb_civet_other.id = 1
      lambda{cb_civet.add_prerequisites(:for_setup, cb_civet_other,"-")}.should raise_error("Cannot add a prerequisite for a task that depends on itself!")
    end

    it "should delete task on task_list if needed state == '-'" do
      cb_civet.prerequisites = {:for_setup => {"T#{cb_civet_other.id}" => "Completed", "T#{cb_civet_other.id + 1}" => "Completed"}}
      cb_civet.add_prerequisites(:for_setup, cb_civet_other,"-")
      cb_civet.prerequisites.should be =~ {:for_setup => {"T#{cb_civet_other.id + 1}" => "Completed"}}
    end

    it "should add task on task_list if needed state != '-'" do
      cb_civet.prerequisites = {:for_setup => {"T#{cb_civet_other.id + 1}" => "Completed"}}
      cb_civet.add_prerequisites(:for_setup, cb_civet_other)
      cb_civet.prerequisites.should be =~ {:for_setup => {"T#{cb_civet_other.id}" => "Completed", "T#{cb_civet_other.id + 1}" => "Completed"}}
    end
    
  end


  
  describe "remove_prerequisites" do

    it "should call remove_prerequisites" do 
      cb_civet.should_receive(:add_prerequisites).with("for_what","othertask","-").and_return("")
      cb_civet.remove_prerequisites("for_what","othertask")
    end
    
  end


  
  describe "add_prerequisites_for_setup" do
    
    it "should call add_prerequisites with :for_setup" do 
      cb_civet.should_receive(:add_prerequisites).with(:for_setup, "othertask", "Completed").and_return("")
      cb_civet.add_prerequisites_for_setup("othertask")
    end
      
  end


  
  describe "add_prerequisites_for_post_processing" do
    
    it "should call add_prerequisites with :for_post_processing" do 
      cb_civet.should_receive(:add_prerequisites).with(:for_post_processing, "othertask", "Completed").and_return("")
      cb_civet.add_prerequisites_for_post_processing("othertask")
    end
        
  end


  
  describe "remove_prerequisites_for_setup" do
      
    it "should call remove_prerequisites with :for_setup" do
      cb_civet.should_receive(:remove_prerequisites).with(:for_setup, "othertask").and_return("")
      cb_civet.remove_prerequisites_for_setup("othertask")
    end
    
  end


  
  describe "remove_prerequisites_for_post_processing" do

    it "should call remove_prerequisites with :for_setup" do
      cb_civet.should_receive(:remove_prerequisites).with(:for_post_processing, "othertask").and_return("")
      cb_civet.remove_prerequisites_for_post_processing("othertask")
    end
    
  end


  
  describe "share_workdir_with" do 
    let!(:cb_civet_other) {Factory.create("cbrain_task/civet")}

    it "should raise an error if othertask.id is nil" do
      cb_civet_other.id = nil
      lambda{cb_civet.share_workdir_with(cb_civet_other)}.should raise_error("No task or task ID provided?")
    end

    it "should set share_wd_tid with othertask.id" do 
      cb_civet.share_workdir_with(cb_civet_other)
      cb_civet.share_wd_tid.should be ==  cb_civet_other.id
    end

    it "should call add_prerequisites_for_setup on self" do
      cb_civet.should_receive(:add_prerequisites_for_setup)
      cb_civet.share_workdir_with(cb_civet_other)
    end

  end


  
  describe "addlog_exception" do 
    
    it "should call addlog only one times if backtrace_lines == 0 and return true" do
      exception = (0..10).to_a
      exception.stub!(:message)
      exception.stub!(:backtrace)
      cb_civet.should_receive(:addlog).at_least(1)
      cb_civet.addlog_exception(exception,"",0).should be_true
    end

    it "should call addlog only exception.backtrace.size + 1 if backtrace_lines >= exception.backtrace.size" do 
      exception = (0..10).to_a
      exception.stub!(:message)
      exception.stub!(:backtrace).and_return(exception)
      cb_civet.should_receive(:addlog).at_least(exception.size + 1)
      cb_civet.addlog_exception(exception)
    end

    it "should call addlog only backtrace_lines + 1 if backtrace_lines < exception.backtrace.size" do 
      exception = (0..20).to_a
      backtrace_lines=15
      exception.stub!(:message)
      exception.stub!(:backtrace).and_return(exception)
      cb_civet.should_receive(:addlog).at_least(backtrace_lines + 1)
      cb_civet.addlog_exception(exception,"",backtrace_lines)
    end
    
  end


  
  describe "addlog_current_resource_revision" do 

    it "should call addlog with specific string and return true" do
      rr     = double("rr")
      RemoteResource.stub!(:current_resource).and_return(rr)
      rr.stub!(:class).and_return("class")
      rrinfo = double("rrinfo")
      rr.stub!(:info).and_return(rrinfo)
      rrinfo.stub!(:starttime_revision).and_return("1")
      call_with = "class rev. 1 "
      cb_civet.should_receive(:addlog).with(call_with, :caller_level => 1)
      cb_civet.addlog_current_resource_revision.should be_true 
    end
  
  end
  
end

