
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

describe CbrainTask do
  let!(:cb_diagnostic) { create("cbrain_task/diagnostics") }
  let(:cb_tool)        { double("tool", :name => "Tool!") }

  context "Utility Methods" do

    describe "name" do

      it "should return a simple name for task" do
        expect(cb_diagnostic.name).to eq("Diagnostics")
      end

    end



    describe "name_and_bourreau" do

      it "should return name@bourreau with (Unknown) if no bourreau is know" do
        allow(cb_diagnostic).to receive_message_chain(:bourreau, :name).and_raise(StandardError)
        expect(cb_diagnostic.name_and_bourreau).to eq("#{cb_diagnostic.name}@(Unknown)")
      end

      it "should return name@bourreau" do
        bourreau = cb_diagnostic.bourreau.name
        expect(cb_diagnostic.name_and_bourreau).to eq("#{cb_diagnostic.name}@#{bourreau}")
      end

    end



    describe "fullname" do

      it "should return name@MyBourreau/id if task have id" do
        bourreau = cb_diagnostic.bourreau.name
        result = "#{cb_diagnostic.name}@#{bourreau}/#{cb_diagnostic.id}"
        expect(cb_diagnostic.fullname).to eq(result)
      end

      it "should return name@MyBourreau/(NoId) if task have no id" do
        bourreau = cb_diagnostic.bourreau.name
        cb_diagnostic.id = nil
        result = "#{cb_diagnostic.name}@#{bourreau}/(NoId)"
        expect(cb_diagnostic.fullname).to eq(result)
      end

    end



    describe "pretty_name" do

      it "should return name" do
        allow(CbrainTask).to receive(:tool).and_return(cb_tool)
        expect(cb_diagnostic.pretty_name).to eq(cb_tool.name)
      end

    end



    describe "self.pretty_name" do

      it "should return a simple name for task" do
        allow(CbrainTask).to receive(:tool).and_return(cb_tool)
        expect(CbrainTask.pretty_name).to eq(cb_tool.name)
      end

    end



    describe "self.tool" do

      it "should call where on Tool" do
        expect(Tool).to receive(:where).and_return([1])
        CbrainTask.tool
      end

    end



    describe "tool" do

      it "should call class and tool on self" do
        my_class = double("class")
        allow(cb_diagnostic).to receive(:class).and_return(my_class)
        expect(my_class).to receive(:tool).and_return("tools")
        cb_diagnostic.tool
      end

    end



    describe "self.pseudo_sort_columns" do

      it "should return [\"batch\"]" do
        expect(CbrainTask.pseudo_sort_columns).to eq(["batch"])
      end

    end



    describe "to_xml" do

      it "should start with '<?xml'" do
        expect(cb_diagnostic.to_xml).to match(/^<\?xml/)
      end

      it "should end with '</subclass>'" do
        expect(cb_diagnostic.to_xml).to match(/\/diagnostics>$/)
      end

    end



    describe "full_cluster_workdir" do

      it "should not called cluster_shared_dir if cluster_workdir is blank" do
        allow(cb_diagnostic).to receive(:cluster_workdir).and_return(nil)
        expect(cb_diagnostic).not_to receive(:cluster_shared_dir)
        cb_diagnostic.full_cluster_workdir
      end

      it "should called cluster_shared_dir in other case" do
        allow(cb_diagnostic).to receive(:cluster_workdir).and_return("val")
        expect(cb_diagnostic).to receive(:cluster_shared_dir).and_return("path")
        expect(cb_diagnostic.full_cluster_workdir).to eq("path/val")
      end

    end



    describe "cluster_shared_dir" do

      it "should raise an error if task have no bourreau" do
        allow(cb_diagnostic).to receive(:bourreau).and_return(nil)
        expect{cb_diagnostic.cluster_shared_dir}.to raise_error(CbrainError, /No Bourreau associated/)
      end

      it "should raise an error if cluster shared directory not defined for Bourreau" do
        mybourreau = double("mybourreau")
        allow(cb_diagnostic).to receive(:bourreau).and_return(mybourreau)
        allow(mybourreau).to receive(:cms_shared_dir).and_return("")
        expect{cb_diagnostic.cluster_shared_dir}.to raise_error(RSpec::Mocks::MockExpectationError, /received unexpected message/)
      end

      it  "should return shared directory in other case" do
        mybourreau = double("mybourreau")
        allow(cb_diagnostic).to receive(:bourreau).and_return(mybourreau)
        shared_dir = double("shared")
        allow(mybourreau).to receive(:cms_shared_dir).and_return(shared_dir)
        expect(cb_diagnostic.cluster_shared_dir).to eq(shared_dir)
      end

    end


    describe "short_description" do

      it "should raise an error if we only have a new line" do
        allow(cb_diagnostic).to receive(:description).and_return("\n")
        expect{cb_diagnostic.short_description}.to raise_error(RuntimeError, /Internal error/)
      end

      it "should return only the last line" do
        allow(cb_diagnostic).to receive(:description).and_return("first line\nsecond line")
        expect(cb_diagnostic.short_description).to eq("first line")
      end

    end

  end



  context "Useful ID Generators" do

    describe "bname_tid" do #OK

      it "should return a string '?/?'" do
        cb_diagnostic.bourreau.name = nil
        cb_diagnostic.id = nil
        expect(cb_diagnostic.bname_tid).to eq("?/?")
      end

      it "should return a string 'bname/?'" do
        cb_diagnostic.id = nil
        expect(cb_diagnostic.bname_tid).to eq("#{cb_diagnostic.bourreau.name}/?")
      end

      it "should return a string '?/tid'" do
        cb_diagnostic.bourreau.name = nil
        expect(cb_diagnostic.bname_tid).to eq("?/#{cb_diagnostic.id}")
      end


      it "should return a string 'bname/tid'" do
        expect(cb_diagnostic.bname_tid).to eq("#{cb_diagnostic.bourreau.name}/#{cb_diagnostic.id}")
      end

    end



    describe "bname_tid_dashed" do

      it "should return a string 'Unk-Unk'" do
        cb_diagnostic.bourreau.name = nil
        cb_diagnostic.id = nil
        expect(cb_diagnostic.bname_tid_dashed).to eq("Unk-Unk")
      end

      it "should return a string 'bname-Unk'" do
        cb_diagnostic.id = nil
        expect(cb_diagnostic.bname_tid_dashed).to eq("#{cb_diagnostic.bourreau.name}-Unk")
      end

      it "should return a string 'Unk-tid'" do
        cb_diagnostic.bourreau.name = nil
        expect(cb_diagnostic.bname_tid_dashed).to eq("Unk-#{cb_diagnostic.id}")
      end


      it "should return a string 'bname-tid'" do
        expect(cb_diagnostic.bname_tid_dashed).to eq("#{cb_diagnostic.bourreau.name}-#{cb_diagnostic.id}")
      end

    end

  end



  context "Run Number ID Methods"

    describe "run_number" do

      it "should return 1 if is nil" do
        cb_diagnostic.run_number = nil
        expect(cb_diagnostic.run_number).to eq(1)
      end

      it "should return run_number value if is not nil" do
        cb_diagnostic.run_number = 2
        expect(cb_diagnostic.run_number).to eq(2)
      end

    end



    describe "run_id" do

      it "should return a string 'task_id-run_number' where run_number is an arg" do
        arg    = 3
        result = "#{cb_diagnostic.id}-#{arg}"
        expect(cb_diagnostic.run_id(arg)).to eq(result)
      end

      it "should return a string 'task_id-run_number where run_number is self.run_number'" do
        run_number = 5
        result = "#{cb_diagnostic.id}-#{run_number}"
        allow(cb_diagnostic).to receive(:run_number).and_return(run_number)
        expect(cb_diagnostic.run_id).to eq(result)
      end

  end



  describe "log_params_changes" do #PB

    it "should changed value if params have same key with different value" do
      cb_diagnostic.log_params_changes({:key1 => "val1"},{:key1 => "val2"})
      expect(cb_diagnostic.getlog).to match(/Changed key \:key1\, old=\"val1\"\, new=\"val2\"/)
    end

    it "should can't compare value if params have same key and data is not comparable" do
      class M < String
        def ==(other)
          return true if other.size == self.size
        end
      end

      val1 = M.new
      val2 = Exception.new("error")

      cb_diagnostic.log_params_changes({:key1 => val1},{:key1 => val2})
      expect(cb_diagnostic.getlog).to  match(/Uncomparable key :key1, old=#{val1.inspect}, new=#{val2.inspect}/)
    end

    it "should deleted key if new_params have no more the key" do
      cb_diagnostic.log_params_changes({:key1 => "val1"},{})
      expect(cb_diagnostic.getlog).to match(/Deleted key :key1 with value \"val1\"/)
    end

    it "should added key if new_params have new key" do
      cb_diagnostic.log_params_changes({},{:key1 => "val1"})
      expect(cb_diagnostic.getlog).to match(/Added key :key1 with value \"val1\"/)
    end

    it "should add 'Total of' in log if numchange > 0" do
      cb_diagnostic.log_params_changes({:key1 => "val1"},{:key1 => "val2"})
      expect(cb_diagnostic.getlog).to match(/Total of 1 changes observed./)
    end

  end



  describe "add_prerequisites" do
    let!(:cb_diagnostic_other) { create("cbrain_task/diagnostics") }

    it "should return an error if 'for_what' isn't ':for_setup' or ':for_post_processing'" do
      expect{cb_diagnostic.add_prerequisites("for_what", cb_diagnostic_other)}.to raise_error("Prerequisite argument 'for_what' must be :for_setup or :for_post_processing")
    end

    it "should return an error if needed state is not allowed" do
      expect{cb_diagnostic.add_prerequisites(:for_setup, cb_diagnostic_other,"not_allowed")}.to raise_error("Prerequisite argument needed_state='not_allowed' is not allowed.")
    end

    it "should return error if other_task id is blank" do
      cb_diagnostic_other.id = ""
      expect{cb_diagnostic.add_prerequisites(:for_setup, cb_diagnostic_other,"-")}.to raise_error("Cannot add a prerequisite based on a task that has no ID yet!")
    end

    it "should return error if self.id == otask_id" do
      cb_diagnostic.id = cb_diagnostic_other.id = 1
      expect{cb_diagnostic.add_prerequisites(:for_setup, cb_diagnostic_other,"-")}.to raise_error("Cannot add a prerequisite for a task that depends on itself!")
    end

    it "should delete task on task_list if needed state == '-'" do
      cb_diagnostic.prerequisites = {:for_setup => {"T#{cb_diagnostic_other.id}" => "Completed", "T#{cb_diagnostic_other.id + 1}" => "Completed"}}
      cb_diagnostic.add_prerequisites(:for_setup, cb_diagnostic_other,"-")
      expect(cb_diagnostic.prerequisites).to match({:for_setup => {"T#{cb_diagnostic_other.id + 1}" => "Completed"}})
    end

    it "should add task on task_list if needed state != '-'" do
      cb_diagnostic.prerequisites = {:for_setup => {"T#{cb_diagnostic_other.id + 1}" => "Completed"}}
      cb_diagnostic.add_prerequisites(:for_setup, cb_diagnostic_other)
      expect(cb_diagnostic.prerequisites).to match({:for_setup => {"T#{cb_diagnostic_other.id}" => "Completed", "T#{cb_diagnostic_other.id + 1}" => "Completed"}})
    end

  end



  describe "remove_prerequisites" do

    it "should call remove_prerequisites" do
      expect(cb_diagnostic).to receive(:add_prerequisites).with("for_what","othertask","-").and_return("")
      cb_diagnostic.remove_prerequisites("for_what","othertask")
    end

  end



  describe "add_prerequisites_for_setup" do

    it "should call add_prerequisites with :for_setup" do
      expect(cb_diagnostic).to receive(:add_prerequisites).with(:for_setup, "othertask", "Completed").and_return("")
      cb_diagnostic.add_prerequisites_for_setup("othertask")
    end

  end



  describe "add_prerequisites_for_post_processing" do

    it "should call add_prerequisites with :for_post_processing" do
      expect(cb_diagnostic).to receive(:add_prerequisites).with(:for_post_processing, "othertask", "Completed").and_return("")
      cb_diagnostic.add_prerequisites_for_post_processing("othertask")
    end

  end



  describe "remove_prerequisites_for_setup" do

    it "should call remove_prerequisites with :for_setup" do
      expect(cb_diagnostic).to receive(:remove_prerequisites).with(:for_setup, "othertask").and_return("")
      cb_diagnostic.remove_prerequisites_for_setup("othertask")
    end

  end



  describe "remove_prerequisites_for_post_processing" do

    it "should call remove_prerequisites with :for_setup" do
      expect(cb_diagnostic).to receive(:remove_prerequisites).with(:for_post_processing, "othertask").and_return("")
      cb_diagnostic.remove_prerequisites_for_post_processing("othertask")
    end

  end



  describe "share_workdir_with" do
    let!(:cb_diagnostic_other) {mock_model(CbrainTask, :id => 1239191).as_null_object}

    it "should raise an error if othertask.id is nil" do
      allow(cb_diagnostic_other).to receive(:id).and_return(nil)
      expect{cb_diagnostic.share_workdir_with(cb_diagnostic_other)}.to raise_error("No task or task ID provided?")
    end

    it "should set share_wd_tid with othertask.id" do
      expect(cb_diagnostic).to receive(:share_wd_tid=).with(cb_diagnostic_other.id)
      cb_diagnostic.share_workdir_with(cb_diagnostic_other)
    end

    it "should call add_prerequisites_for_setup on self" do
      expect(cb_diagnostic).to receive(:add_prerequisites_for_setup)
      cb_diagnostic.share_workdir_with(cb_diagnostic_other)
    end

  end



  describe "addlog_exception" do
    let!(:my_exception) {double("exception").as_null_object}

    it "should call addlog only one times if backtrace_lines == 0 and return true" do
      expect(cb_diagnostic).to receive(:addlog).at_least(1)
      expect(cb_diagnostic.addlog_exception(my_exception,"",0)).to be_truthy
    end

    it "should call addlog only once if exception is not a CbrainException" do
      allow(my_exception).to   receive(:is_a?).and_return(true)
      expect(cb_diagnostic).to receive(:addlog).at_least(1)
      cb_diagnostic.addlog_exception(my_exception)
      expect(cb_diagnostic.addlog_exception(my_exception)).to be_truthy
    end

    it "should call addlog only backtrace_lines + 1 if backtrace_lines < exception.backtrace.size" do
      backtrace_lines=15
      allow(my_exception).to receive_message_chain(:backtrace,:size).and_return(backtrace_lines)
      allow(my_exception).to receive_message_chain(:cbrain_backtrace, :[]).and_return((0..backtrace_lines).to_a)
      expect(cb_diagnostic).to receive(:addlog).at_least(backtrace_lines + 1)
      cb_diagnostic.addlog_exception(my_exception, "", backtrace_lines)
    end

  end



  describe "addlog_current_resource_revision" do

    it "should call addlog with specific string and return true" do
      rr     = double("rr")
      allow(RemoteResource).to receive(:current_resource).and_return(rr)
      allow(rr).to receive(:class).and_return("class")
      rrinfo = double("rrinfo")
      allow(rr).to receive(:info).and_return(rrinfo)
      allow(rrinfo).to receive(:starttime_revision).and_return("1")
      call_with = "class rev. 1 "
      expect(cb_diagnostic).to receive(:addlog).with(call_with, :caller_level => 1)
      expect(cb_diagnostic.addlog_current_resource_revision).to be_truthy
    end

  end

end

