
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

describe ClusterTask do
  let!(:cluster_task)    {Factory.create("cbrain_task/civet")}
  let!(:userfile1)       {Factory.create(:userfile)}
  let!(:userfile2)       {Factory.create(:userfile)}
  let!(:userfile3)       {Factory.create(:userfile)}
  let!(:niak_fmri_study) {Factory.create(:niak_fmri_study)}



  context "Core Object Methods" do
    
    describe "record_cbraintask_revs" do 
      
      it "should addlog with rev number" do
        cluster_task.record_cbraintask_revs
        cluster_task.getlog.should =~ /record_cbraintask_revs\(\) cluster_task.rb rev\./
      end
  
    end
  
  end



  context "Main User API Methods setup(), cluster_commands() and save_results()" do

    
    describe "setup" do 

      it "should always return true" do 
        cluster_task.setup.should be_true
      end
      
    end


    describe "cluster_commands" do 
      
      it "should return an array containsing 'true >/dev/null'" do
        cluster_task.cluster_commands.should be =~ [ "true >/dev/null" ]
      end
      
    end


    describe "save_results" do 

      it "should always return true" do
        cluster_task.save_results.should be_true
      end
      
    end

    
    describe "job_walltime_estimate" do 

      it "should return 24.hours" do
        cluster_task.job_walltime_estimate.should be == 24.hours
      end
      
    end
        
  end



  context "Main User API Methods Error recovery and restarts" do

    
    describe "recover_from_setup_failure" do 

      it "should add 'This task is not programmed for recovery.' in log" do
        cluster_task.recover_from_setup_failure
        cluster_task.getlog.should =~ /recover_from_setup_failure\(\) This task is not programmed for recovery\./
      end

      it "should return false" do
        cluster_task.recover_from_setup_failure.should be == false
      end
    
    end


    describe "recover_from_cluster_failure" do 

      it "should add 'This task is not programmed for recovery.' in log" do
        cluster_task.recover_from_cluster_failure
        cluster_task.getlog.should =~ /recover_from_cluster_failure\(\) This task is not programmed for recovery\./
      end

      it "should return false" do
        cluster_task.recover_from_cluster_failure.should be == false
      end
    
    end

    describe "recover_from_post_processing_failure" do 

      it "should add 'This task is not programmed for recovery.' in log" do
        cluster_task.recover_from_post_processing_failure
        cluster_task.getlog.should =~ /recover_from_post_processing_failure\(\) This task is not programmed for recovery\./
      end

      it "should return false" do
        cluster_task.recover_from_post_processing_failure.should be == false
      end
    
    end

    describe "restart_at_setup" do 

      it "should add 'This task is not programmed for restarts.' in log" do
        cluster_task.restart_at_setup
        cluster_task.getlog.should =~ /restart_at_setup\(\) This task is not programmed for restarts\./
      end

      it "should return false" do
        cluster_task.restart_at_setup.should be == false
      end
    
    end


    describe "restart_at_cluster" do 

      it "should add 'This task is not programmed for restarts.' in log" do
        cluster_task.restart_at_cluster
        cluster_task.getlog.should =~ /restart_at_cluster\(\) This task is not programmed for restarts\./
      end

      it "should return false" do
        cluster_task.restart_at_cluster.should be == false
      end
    
    end


    describe "restart_at_post_processing" do 

      it "should add 'This task is not programmed for restarts.' in log" do
        cluster_task.restart_at_post_processing
        cluster_task.getlog.should =~ /restart_at_post_processing\(\) This task is not programmed for restarts\./
      end

      it "should return false" do
        cluster_task.restart_at_post_processing.should be == false
      end
    
    end
    
  end


  
  context "Utility Methods For CbrainTask:ClusterTask Developers" do

    
    describe "safe_mkdir" do 
      before(:each) do
        cluster_task.stub!(:we_are_in_workdir).and_return(true)
      end 
      
      it "should raise an error if we_are_in_workdir" do
        cluster_task.stub!(:we_are_in_workdir).and_return(false)
        lambda{cluster_task.safe_mkdir("path")}.should raise_error("Current directory is not the task's work directory?")
      end

      it "should raise an error if relpath is blank" do
        lambda{cluster_task.safe_mkdir("")}.should raise_error("New directory argument must be a relative path.")
      end

      it "should create a new directory unless File.directory?" do
        Dir.should_receive(:mkdir).and_return("")
        File.stub!(:directory?).and_return(false)
        cluster_task.safe_mkdir("path")
      end

      it "should not create a new directory if File.directory?" do
        Dir.should_not_receive(:mkdir).and_return("")
        File.stub!(:directory?).and_return(true)
        cluster_task.safe_mkdir("path")
      end
    
    end


    describe "safe_symlink" do 
    
      before(:each) do
        cluster_task.stub!(:we_are_in_workdir).and_return(true)
      end 

      it "should raise an error if we_are_in_workdir" do
        cluster_task.stub!(:we_are_in_workdir).and_return(false)
        lambda{cluster_task.safe_symlink("ori","path")}.should raise_error("Current directory is not the task's work directory?")
      end

      it "should raise an error if relpath is blank" do
        lambda{cluster_task.safe_symlink("ori","")}.should raise_error("New directory argument must be a relative path.")
      end

      it "should unlink symlink if File.symlink?" do
        File.should_receive(:unlink).and_return("")
        File.stub!(:symlink?).and_return(true)
        File.stub!(:symlink).and_return("")
        cluster_task.safe_symlink("ori","path")
      end

      it "should create a new symlink" do
        File.should_receive(:symlink).and_return("")
        cluster_task.safe_symlink("ori","path")
      end
    
    end
  
   
    describe "safe_userfile_find_or_new" do 

      it "should raise an error if class for file is not a subclass of Userfile" do
        lambda{cluster_task.safe_userfile_find_or_new(String,{})}.should raise_error(/must be a subclass/)
      end

      it "should raise an error if a required attribute missing" do
        lambda{cluster_task.safe_userfile_find_or_new(MincFile,{})}.should raise_error("Attribute list missing a required attribute.")
      end

      it "should raise an error if cannot assign user to file" do
        cluster_task.user_id = nil
        lambda{cluster_task.safe_userfile_find_or_new(MincFile,{:name => "name", :data_provider_id => 1})}.should raise_error("Cannot assign user to file.")
      end

      it "should raise an error if cannot assign a group to file" do
        cluster_task.group_id = nil
        lambda{cluster_task.safe_userfile_find_or_new(MincFile,{:name => "name", :data_provider_id => 1, :user_id => 1})}.should raise_error("Cannot assign group to file.")
      end 

      it "should test return userfile corresponding to attribute" do
        attlist = {:name => niak_fmri_study.name, :data_provider_id => niak_fmri_study.data_provider_id, :user_id => niak_fmri_study.user_id, :group_id => niak_fmri_study.group_id }
        cluster_task.safe_userfile_find_or_new(NiakFmriStudy, attlist).should be == niak_fmri_study
      end 
      
      it "should raise an error if found more than one file that match attribute list." do
        attlist = {:name => niak_fmri_study.name, :data_provider_id => niak_fmri_study.data_provider_id, :user_id => niak_fmri_study.user_id, :group_id => niak_fmri_study.group_id }
        MincFile.stub!(:where).and_return(Userfile)
        lambda{cluster_task.safe_userfile_find_or_new(MincFile, attlist)}.should raise_error(/Found more than one file/)
      end

      it "should create a new klass file" do
        attlist = {:name => "new_name", :data_provider_id => niak_fmri_study.data_provider_id, :user_id => niak_fmri_study.user_id, :group_id => niak_fmri_study.group_id }
        NiakFmriStudy.should_receive(:new)
        cluster_task.safe_userfile_find_or_new(NiakFmriStudy, attlist)
      end 
      
    end

    
    describe "we_are_in_workdir" do 

      it "should return false if full_cluster_workdir is blank" do
        cluster_task.stub!(:full_cluster_workdir).and_return("")
        cluster_task.we_are_in_workdir.should be == false
      end

      it "should return true if we are in workdir" do
        cluster_task.stub!(:full_cluster_workdir).and_return(Dir.getwd)
        cluster_task.we_are_in_workdir.should be_true
      end

      it "should return false if we are not in workdir" do
        cluster_task.cluster_workdir = Pathname(Dir.getwd).parent.to_s
        cluster_task.we_are_in_workdir.should be == false
      end
    
    end

    
    describe "addlog_to_userfiles_processed" do 

      it "should add log to each userfile" do
        cluster_task.addlog_to_userfiles_processed([userfile1,userfile2])
        userfile1.getlog.should =~ /Processed by task/
        userfile2.getlog.should =~ /Processed by task/
      end

      it "should add log to each userfile but not to other object" do
        cluster_task.addlog_to_userfiles_processed([userfile1,cluster_task])
        userfile1.getlog.should        =~ /Processed by task/
        cluster_task.getlog.should_not =~ /Processed by task/
      end
        
    end

    
    describe "addlog_to_userfiles_created" do 
         
      it "should add log to each userfile" do
        cluster_task.addlog_to_userfiles_created([userfile1,userfile2])
        userfile1.getlog.should =~ /Created\/updated by/
        userfile2.getlog.should =~ /Created\/updated by/
      end

      it "should add log to each userfile but not to other object" do
        cluster_task.addlog_to_userfiles_created([userfile1,cluster_task])
        userfile1.getlog.should        =~ /Created\/updated by/
        cluster_task.getlog.should_not =~ /Created\/updated by/
      end
      
    end 

    
    describe "addlog_to_userfiles_these_created_these" do 

      it "should add log to each creator userfile" do
        cluster_task.addlog_to_userfiles_these_created_these([userfile1,userfile2],userfile3)
        userfile1.getlog.should =~ /Used by task/
        userfile2.getlog.should =~ /Used by task/
      end
      
      it "should add log to each created userfile" do
        cluster_task.addlog_to_userfiles_these_created_these(userfile1,[userfile2,userfile3])
        userfile2.getlog.should =~ /Created by task/
        userfile3.getlog.should =~ /Created by task/
      end
      
      it "should not add log to creator and to created if creator is not a Userfile" do
        cluster_task.addlog_to_userfiles_created(cluster_task,[userfile1,userfile2])
        cluster_task.getlog.should_not =~ /Used by task/
        userfile1.getlog.should_not    =~ /Created by task/
        userfile2.getlog.should_not    =~ /Created by task/
      end 

      it "should not add log to creator and to created if created is not a Userfile" do
        cluster_task.addlog_to_userfiles_created([userfile1,userfile2],cluster_task)
        cluster_task.getlog.should_not =~ /Created by task/
        userfile1.getlog.should_not    =~ /Used by task/
        userfile2.getlog.should_not    =~ /Used by task/
      end
      
    end

    
    describe "tool_config_system" do 
      before (:each) do
        cluster_task.stub!(:we_are_in_workdir).and_return(true)
        cluster_task.stub_chain(:bourreau, :global_tool_config).and_return(double("bourreau_glob_config").as_null_object)
        cluster_task.stub_chain(:tool, :global_tool_config).and_return(double("tool_glob_config").as_null_object)
        cluster_task.stub!(:tool_config).and_return(double("tool_config").as_null_object)
      end

      it "should return an error if we aren't in workdir" do
        cluster_task.stub!(:we_are_in_workdir).and_return(false)
        lambda{cluster_task.tool_config_system("My command")}.should raise_error()
      end

      it "should called system" do
        cluster_task.should_receive(:system).with(/^\/bin\/bash/)
        cluster_task.tool_config_system("My command") 
      end

      it "should called open on File" do
        File.should_receive(:open)
        cluster_task.tool_config_system("My command")
      end
      
      it "should called unlink on File 3 times" do
        File.should_receive(:unlink).exactly(3)
        cluster_task.tool_config_system("My command")
      end

      it "should return [ 'contains', 'contains'] if File.read not raise an exception" do
        File.stub!(:read).and_return("contains")
        cluster_task.tool_config_system("My command").should be =~ ["contains","contains"]
      end
      
      it "should return ['',''] if File.read raise an exception" do
        File.stub!(:read).and_return(StandardError.new)
        cluster_task.tool_config_system("My command").should be =~ ["",""]
      end
      
    end

    
    describe "supplemental_cbrain_tool_config_init" do 
      
      it "should return a string containsing export PATH" do
        cluster_task.supplemental_cbrain_tool_config_init.should =~ /export PATH=\"#{Rails.root.to_s}/ 
      end
      
    end
    
  end

  

  context "Main Control methods" do 

    describe "setup_and_submit_job" do 
      before (:each) do 
        cluster_task.status = "Setting Up"
        cluster_task.stub!(:make_cluster_workdir).and_return(true)
        cluster_task.stub!(:apply_tool_config_environment).and_return(true)
        cluster_task.stub!(:full_cluster_workdir).and_return(Pathname.new("cache_path"))
        Dir.stub!(:chdir).and_yield
      end
        
      it "should return an error if self.status != 'Setting Up'" do
        cluster_task.status = "Other"
        lambda{cluster_task.setup_and_submit_job}.should raise_error(/Setting Up/)
      end

      it "should Failed to setup and addlog 'returned by setup()'" do
        cluster_task.stub!(:setup).and_return(false)
        cluster_task.setup_and_submit_job
        cluster_task.getlog.should =~ /by setup()./ 
        cluster_task.status.should be == "Failed To Setup"
      end

      it "should Failed to setup and addlog 'returned submit_cluster_job()'" do
        cluster_task.stub!(:setup).and_return(true)
        cluster_task.stub!(:submit_cluster_job).and_return(false)
        cluster_task.setup_and_submit_job
        cluster_task.getlog.should =~ /by submit_cluster_job()./ 
        cluster_task.status.should be == "Failed To Setup" 
      end

      it "should addlog 'Setup and submit' if setup is ok" do
        cluster_task.stub!(:setup).and_return(true)
        cluster_task.stub!(:submit_cluster_job).and_return(true)
        cluster_task.setup_and_submit_job
        cluster_task.status.should be == "Setting Up" 
      end 

      it "should set status to 'Failed...' if go in rescue" do
        cluster_task.stub!(:addlog).and_raise(StandardError.new)
        cluster_task.stub!(:addlog_exception).and_return(true)
        cluster_task.setup_and_submit_job
        cluster_task.status.should =~ /^Failed/ 
      end

      it "should called save on self" do
        cluster_task.should_receive(:save).at_least(:once)
        cluster_task.setup_and_submit_job
      end 

    end

    
    describe "post_process" do 
      before (:each) do 
        cluster_task.status = "Post Processing"
        cluster_task.stub!(:record_cbraintask_revs).and_return(true)
        cluster_task.stub!(:update_size_of_cluster_work).and_return(true)
        cluster_task.stub!(:apply_tool_config_environment).and_return(true)
        cluster_task.stub!(:full_cluster_workdir).and_return(Pathname.new("cache_path"))
        Dir.stub!(:chdir).and_yield
      end
      
      
      it "should return an error if self.status != 'Post Processing'" do
        cluster_task.status = "Other"
        lambda{cluster_task.post_process}.should raise_error(/Post Processing/)
      end


      it "should set status to 'Failed...' and addlog 'Data processing failed'" do
        cluster_task.stub!(:save_results).and_return(false)
        cluster_task.post_process
        cluster_task.getlog.should =~ /Data processing failed/ 
        cluster_task.status.should be == "Failed On Cluster"
      end

      it "should set status to 'Completed' and addlog 'Asynchronous'" do
        cluster_task.stub!(:save_results).and_return(true)
        cluster_task.post_process
        cluster_task.getlog.should =~ /Asynchronous/ 
        cluster_task.status.should be == "Completed" 
      end
    

      it "should set status to 'Failed...' if go in rescue" do
        cluster_task.stub!(:addlog).and_raise(StandardError.new)
        cluster_task.stub!(:addlog_exception).and_return(true)
        cluster_task.post_process
        cluster_task.status.should =~ /^Failed/ 
      end
    
      it "should called save on self" do
        cluster_task.should_receive(:save).at_least(:once)
        cluster_task.post_process
      end 
      
    end

    
    describe "update_status" do 

      it "should return an error if status is blank" do
        cluster_task.status = ""
        lambda{cluster_task.update_status}.should raise_error(/Unknown blank/)
      end

      it "should return status if match with specific pattern" do
        cluster_task.status = "Duplicated"
        cluster_task.update_status.should be == "Duplicated" 
      end

      it "should update status with cluster_status if clusterstatus.match with specific string" do
        cluster_task.status = "Other"
        cluster_task.stub(:cluster_status).and_return("On CPU")
        cluster_task.should_receive(:status_transition).with(cluster_task.status, "On CPU").and_return(true)
        cluster_task.update_status
      end

      it "should update status with 'Data Ready' if self.status match with specific string" do
        cluster_task.status = "On CPU"
        cluster_task.stub(:cluster_status).and_return("Other")
        cluster_task.should_receive(:status_transition).with(cluster_task.status, "Data Ready").and_return(true)
        cluster_task.update_status
      end

      it "should raise an error if no return made before end of method" do
        cluster_task.status = "Other"
        cluster_task.stub(:cluster_status).and_return("Other")
        lambda{cluster_task.update_status}.should raise_error(/Cluster job finished/)
      end
      
    end

    
    describe "status_transition" do 
      
      it "should return false if self.status != from_state" do
        cluster_task.status = "On CPU"
        cluster_task.save!
        cluster_task.status_transition("New","On CPU").should be false
      end

      it "should return true if from_state == to_state" do
        cluster_task.status_transition("New","New").should be_true
      end

      it "should change status" do
        cluster_task.status_transition("New","On CPU")
        cluster_task.status.should be == "On CPU" 
      end

      it "should return true if go at end of method" do
        cluster_task.status_transition("New","On CPU").should be_true
      end
      
    end

    
    describe "status_transition!" do 

      it "should raise a CbrainTransitionException" do
        cluster_task.status = "On CPU"
        cluster_task.save!
        lambda{cluster_task.status_transition!("New","On CPU")}.should raise_error
      end

      it "should return true if all is OK" do
        cluster_task.status_transition!("New","New").should be_true
      end 

    end
      
  end


  
  context "Task Control Method" do
    let!(:bourreau) {Factory.create(:bourreau)}
    
    describe "terminate" do 
      before (:each) do
        cluster_task.stub_chain(:scir_session, :terminate).and_return(true)
      end

      it "should changed status for Terminated if cur_status match with 'On CPU'" do
        cluster_task.status = "On CPU"
        cluster_task.save
        cluster_task.terminate
        cluster_task.status.should be == "Terminated"
      end

      it "should changed status for Terminated if cur_status == 'New'" do
        cluster_task.status = "New"
        cluster_task.save
        cluster_task.terminate
        cluster_task.status.should be == "Terminated"
      end

      context "updated_at < 8.hours" do

        it "should change status for 'Failed To Setup' if status == 'Setting Up'" do
          cluster_task.status = "Setting Up"
          cluster_task.updated_at = 9.hours.ago
          cluster_task.save
          cluster_task.terminate
          cluster_task.status.should be == "Failed To Setup"
        end

        it "should change status for 'Failed To PostProcess' if status == 'Post Processing'" do
          cluster_task.status = "Post Processing"
          cluster_task.updated_at = 9.hours.ago
          cluster_task.save
          cluster_task.terminate
          cluster_task.status.should be == "Failed To PostProcess"
        end

        it "should change status for 'Failed To Setup' if status =~ /(Recovering|Restarting) Setup/" do
          cluster_task.status = "Recovering Setup"
          cluster_task.updated_at = 9.hours.ago
          cluster_task.save
          cluster_task.terminate
          cluster_task.status.should be == "Failed To Setup"
        end

        it "should change status for 'Failed On Cluster' if status =~ /(Recovering|Restarting) Cluster/" do
          cluster_task.status = "Recovering Cluster"
          cluster_task.updated_at = 9.hours.ago
          cluster_task.save
          cluster_task.terminate
          cluster_task.status.should be == "Failed On Cluster"
        end

        it "should change status for 'Failed To PostProcess' if status =~ /(Recovering|Restarting) PostProcess/" do
          cluster_task.status = "Recovering PostProcess"
          cluster_task.updated_at = 9.hours.ago
          cluster_task.save
          cluster_task.terminate
          cluster_task.status.should be == "Failed To PostProcess"
        end

        it "in other case status should be 'Terminated'" do
          cluster_task.status = "Setting Up Other"
          cluster_task.updated_at = 9.hours.ago
          cluster_task.save
          cluster_task.terminate
          cluster_task.status.should be == "Terminated"
        end
      
      end                          

      it "should return false if go at the end of method and not changed status" do
        cluster_task.status = "Setting Up"
        cluster_task.save
        cluster_task.terminate.should be false
        cluster_task.status.should be == "Setting Up"
      end 
      
      it "should return false if go in rescue" do
        cluster_task.status = "On CPU"
        cluster_task.save
        cluster_task.stub_chain(:scir_session, :terminate).and_raise(StandardError.new)
        cluster_task.terminate.should be false
        cluster_task.status.should be == "On CPU"
      end
      
    end

    
    describe "suspend" do 
      it "should return false id status != 'On CPU'" do
        cluster_task.suspend.should be false
      end

      it "should change status for 'Suspended' if no exception" do
        cluster_task.status = "On CPU"
        cluster_task.save!
        cluster_task.stub_chain(:scir_session, :suspend).and_return(true)
        cluster_task.suspend
        cluster_task.status.should be == "Suspended"
      end

      it "should return false if go in rescue" do
        cluster_task.status = "On CPU"
        cluster_task.save!
        cluster_task.stub_chain(:scir_session, :suspend).and_raise(StandardError.new)
        cluster_task.suspend.should be false
      end
      
    end

    
    describe "resume" do 

      it "should return false id status != 'Suspended'" do
        cluster_task.resume.should be false
      end

      it "should change status for 'On CPU' if no exception" do
        cluster_task.status = "On CPU"
        cluster_task.save!
        cluster_task.stub_chain(:scir_session, :resume).and_return(true)
        cluster_task.resume
        cluster_task.status.should be == "On CPU"
      end

      it "should return false if go in rescue" do
        cluster_task.status = "Suspended"
        cluster_task.save!
        cluster_task.stub_chain(:scir_session, :resume).and_raise(StandardError.new)
        cluster_task.resume.should be false
      end
      
    end

    
    describe "hold" do 

      it "should return false id status != 'Queued'" do
        cluster_task.hold.should be false
      end

      it "should change status for 'On CPU' if no exception" do
        cluster_task.status = "Queued"
        cluster_task.save!
        cluster_task.stub_chain(:scir_session, :hold).and_return(true)
        cluster_task.hold
        cluster_task.status.should be == "On Hold"
      end

      it "should return false if go in rescue" do
        cluster_task.status = "Queued"
        cluster_task.save!
        cluster_task.stub_chain(:scir_session, :release).and_raise(StandardError.new)
        cluster_task.hold.should be false
      end
      
    end


    describe "release" do 

      it "should return false id status != 'On Hold'" do
        cluster_task.release.should be false
      end

      it "should change status for 'On CPU' if no exception" do
        cluster_task.status = "On Hold"
        cluster_task.save!
        cluster_task.stub_chain(:scir_session, :release).and_return(true)
        cluster_task.release
        cluster_task.status.should be == "Queued"
      end

      it "should return false if go in rescue" do
        cluster_task.status = "On Hold"
        cluster_task.save!
        cluster_task.stub_chain(:scir_session, :resume).and_raise(StandardError.new)
        cluster_task.release.should be false
      end
      
    end 
    
  end


  
  context "Methods for recovering / restarting" do

    
    describe "recover" do 

      it "should set status to 'New' if status 'Failed Setup Prerequisites'" do
        cluster_task.status = "Failed Setup Prerequisites"
        cluster_task.save
        cluster_task.recover
        cluster_task.status.should be == "New"
      end
         
      it "should set status to 'Data Ready' if status 'Failed PostProcess Prerequisites'" do
        cluster_task.status = "Failed PostProcess Prerequisites"
        cluster_task.save
        cluster_task.recover
        cluster_task.status.should be == "Data Ready"
      end

      it "should not change status and return false if status doesn't match with specific string" do
        cluster_task.status = "New"
        cluster_task.save
        cluster_task.recover.should be false
        cluster_task.status.should be == "New"
      end

      it "should change status to 'Recover Setup' if status =~ /Failed To Setup/" do
        cluster_task.status = "Failed To Setup"
        cluster_task.save
        cluster_task.recover
        cluster_task.status.should be == "Recover Setup"
      end

      it "should change status to 'Recover Cluster' if status =~ /Failed On Cluster/" do
        cluster_task.status = "Failed On Cluster"
        cluster_task.save
        cluster_task.recover
        cluster_task.status.should be == "Recover Cluster"
      end

      it "should change status to 'Recover PostProcess' if status =~ /Failed To PostProcess/" do
        cluster_task.status = "Failed To PostProcess"
        cluster_task.save
        cluster_task.recover
        cluster_task.status.should be == "Recover PostProcess"
      end 

      it "should return false if go in rescue" do
        cluster_task.stub!(:addlog).and_raise(StandardError.new)
        cluster_task.status = "Failed To PostProcess"
        cluster_task.save
        cluster_task.recover.should be false
        cluster_task.status.should be == "Failed To PostProcess"
      end 

      
    end

    
    describe "restart" do 

      it "should return false and not updated status if status !~ /Completed|Terminated/" do
        cluster_task.status = "On CPU"
        cluster_task.save
        cluster_task.restart.should be false
        cluster_task.status.should be == "On CPU"
      end

      it "should return false and not updated status if restart option !~ /Setup|Cluster|PostProcess/" do
        cluster_task.restart("On CPU")
        cluster_task.restart.should be false
        cluster_task.status.should be == "New"
      end

      it "should set status to 'Restart Setup' if status is Terminated (forced)" do
        cluster_task.status = "Terminated"
        cluster_task.save
        cluster_task.restart("Cluster").should be_true
        cluster_task.status.should be == "Restart Setup"
      end

      it "should set status to 'Restart \#{atwhat}' if status is Terminated" do
        cluster_task.status = "Completed"
        cluster_task.save
        cluster_task.restart("Cluster").should be_true
        cluster_task.status.should be == "Restart Cluster"
      end

      it "should return false and doesn't changed status if go in rescue" do
        cluster_task.status = "Terminated"
        cluster_task.save
        cluster_task.stub!(:addlog).and_raise(StandardError.new)
        cluster_task.restart.should be false
        cluster_task.status.should be == "Terminated"
      end
           
    end 
  
  end


  
  context "Prerequisites Fulfillment Evaluation Methods" do


    describe "prerequisites_fulfilled?" do
      let!(:cluster_task1)    {Factory.create("cluster_task")}

      it "should return ':go' if prereqs is empty" do
        cluster_task.prerequisites = {}
        cluster_task.save
        cluster_task.prerequisites_fulfilled?("Setup").should be == :go
      end

      it "should go in rescue with a cb_error if prerq key is invalid" do
        cluster_task.prerequisites = { "Setup" => {"A62" => "Completed"}}
        cluster_task.save
        cluster_task.prerequisites_fulfilled?("Setup").should be == :fail 
        cluster_task.getlog.should =~ /CBRAIN Error.+Invalid prereq key/
      end

      it "should go in rescue with a cb_notice if prereq key is itself.id" do
        cluster_task.prerequisites = { "Setup" => {"T#{cluster_task.id}" => "Completed"}}
        cluster_task.save
        cluster_task.prerequisites_fulfilled?("Setup").should be == :fail 
        cluster_task.getlog.should =~ /Failure.+on itself/
      end

      it "should go in rescue with a cb_error if no task was found with prereq key" do
        cluster_task.prerequisites = { "Setup" => {"T62" => "Completed"}}
        cluster_task.save
        CbrainTask.stub!(:find).and_return(nil)
        cluster_task.prerequisites_fulfilled?("Setup").should be == :fail 
        cluster_task.getlog.should =~ /CBRAIN Error.+not find task/
      end

      it "should go in rescue with a cb_error if needed_state not found" do
        cluster_task.prerequisites = { "Setup" => {"T#{cluster_task1.id}" => "Other"}}
        cluster_task.save
        cluster_task.prerequisites_fulfilled?("Setup").should be == :fail 
        cluster_task.getlog.should =~ /CBRAIN Error.+not found coverage/
      end

      it "should return :go if status of prereq task correspond to needed state" do
        cluster_task.prerequisites = { "Setup" => {"T#{cluster_task1.id}" => "Completed"}}
        cluster_task1.status = "Completed"
        cluster_task1.save
        cluster_task.should_not_receive(:addlog)
        cluster_task.prerequisites_fulfilled?("Setup").should be == :go 
      end

      it "should go in rescue with a cb_notice if action is fail" do
        cluster_task.prerequisites = { "Setup" => {"T#{cluster_task1.id}" => "Completed"}}
        cluster_task1.status = "Terminated"
        cluster_task1.save
        cluster_task.prerequisites_fulfilled?("Setup").should be == :fail
        cluster_task.getlog.should =~ /Failure.+while we wanted/
      end
      
    end 
    
  end 


  
  context "ActiveRecord Lifecycle methods" do

    
    describe "before_destroy_terminate_and_rm_workdir" do 
      
      it "should called remove_cluster_workdir on self and return true" do 
        cluster_task.should_receive(:remove_cluster_workdir)
        cluster_task.before_destroy_terminate_and_rm_workdir.should be_true 
      end

    end
  
  end

  

  context "Cluster Job's STDOUT And STDERR Files Methods" do


    describe "qsub_script_basename" do 

      it "should not called name on cluster_task if file doesn't exist" do
        File.stub!(:exists?).and_return(true)
        cluster_task.should_not_receive(:name)
        cluster_task.qsub_script_basename
      end

      it "should called name on cluster_task if file exist" do
        File.stub!(:exists?).and_return(false)
        cluster_task.qsub_script_basename
      end
      
    end

    
    describe "stdout_cluster_filename" do 

      it "should return nil if workdir is blank" do
        cluster_task.stub!(:full_cluster_workdir).and_return("")
        cluster_task.stdout_cluster_filename.should be == nil
      end 

      it "should return \#{workdir}/.qsub.sh.out if file exist" do
        workdir = "workdir" 
        cluster_task.stub!(:full_cluster_workdir).and_return(workdir)
        
        File.stub!(:exists?).and_return do |x|
          if x == "#{workdir}/.qsub.sh.out"
            true
          end
        end

        cluster_task.stdout_cluster_filename.should be == "#{workdir}/.qsub.sh.out"
      end

      it "should return file path with only run_id if exist" do
        workdir = "workdir" 
        cluster_task.stub!(:full_cluster_workdir).and_return(workdir)
        
        File.stub!(:exists?).and_return do |x|
          if x == "#{workdir}/.qsub.sh.out"
            false
          else
            true
          end
        end
        
        cluster_task.stdout_cluster_filename.should =~ /#{workdir}.+#{cluster_task.run_id(nil)}/
      end

      it "should return file path with name and run_id in other case" do
        workdir = "workdir" 
        cluster_task.stub!(:full_cluster_workdir).and_return(workdir)
        File.stub!(:exists?).and_return(false)
        cluster_task.stdout_cluster_filename.should =~ /#{workdir}.+#{cluster_task.name}\.#{cluster_task.run_id(nil)}/
      end

    end


    describe "stderr_cluster_filename" do 

      it "should return nil if workdir is blank" do
        cluster_task.stub!(:full_cluster_workdir).and_return("")
        cluster_task.stderr_cluster_filename.should be == nil
      end 

      it "should return \#{workdir}/.qsub.sh.out if file exist" do
        workdir = "workdir" 
        cluster_task.stub!(:full_cluster_workdir).and_return(workdir)
        
        File.stub!(:exists?).and_return do |x|
          if x == "#{workdir}/.qsub.sh.err"
            true
          end
        end

        cluster_task.stderr_cluster_filename.should be == "#{workdir}/.qsub.sh.err"
      end

      it "should return file path with only run_id if exist" do
        workdir = "workdir" 
        cluster_task.stub!(:full_cluster_workdir).and_return(workdir)
        
        File.stub!(:exists?).and_return do |x|
          if x == "#{workdir}/.qsub.sh.err"
            false
          else
            true
          end
        end
        
        cluster_task.stderr_cluster_filename.should =~ /#{workdir}.+#{cluster_task.run_id(nil)}/
      end

      it "should return file path with name and run_id in other case" do
        workdir = "workdir" 
        cluster_task.stub!(:full_cluster_workdir).and_return(workdir)
        File.stub!(:exists?).and_return(false)
        cluster_task.stderr_cluster_filename.should =~ /#{workdir}.+#{cluster_task.name}\.#{cluster_task.run_id(nil)}/
      end
      
    end


    describe "capture_job_out_err" do 
      before (:each) do
        cluster_task.stub!(:new_record?).and_return(false)
        File.stub!(:exist?).and_return(true)
      end
      

      it "should return nil if cluster_task is a new record" do
        cluster_task.stub!(:new_record?).and_return(true)
        cluster_task.capture_job_out_err.should be == nil
      end

      it "should assign end of stdoutfile to cluster_stdout" do
        cluster_task.stub!(:stdout_cluster_filename).and_return("stdout")
        cluster_task.stub!(:stderr_cluster_filename).and_return(false)
        io = double("io")
        IO.stub!(:popen).and_return(io)
        io.should_receive(:read).and_return("stdout")
        io.stub!(:close)
        cluster_task.capture_job_out_err
        cluster_task.cluster_stdout.should be == "stdout"
      end

      it "should assign end of stderrfile to cluster_stderr" do
        cluster_task.stub!(:stdout_cluster_filename).and_return(false)
        cluster_task.stub!(:stderr_cluster_filename).and_return("stderr")
        io = double("io")
        IO.stub!(:popen).and_return(io)
        io.should_receive(:read).and_return("stderr")
        io.stub!(:close)
        cluster_task.capture_job_out_err
        cluster_task.cluster_stderr.should be == "stderr"
      end

      it "should assign contains of scriptfile to script_text" do
        cluster_task.stub!(:stdout_cluster_filename).and_return(false)
        cluster_task.stub!(:stderr_cluster_filename).and_return(false)
        cluster_task.stub!(:full_cluster_workdir).and_return("wordir")
        cluster_task.stub!(:qsub_script_basename).and_return("")
        File.stub!(:read).and_return("scriptfile")
        cluster_task.capture_job_out_err
        cluster_task.script_text.should be == "scriptfile"
      end 

      it "should assign an empty string to script_text if File.read raise an exception" do
        cluster_task.stub!(:stdout_cluster_filename).and_return(false)
        cluster_task.stub!(:stderr_cluster_filename).and_return(false)
        cluster_task.stub!(:full_cluster_workdir).and_return("wordir")
        cluster_task.stub!(:qsub_script_basename).and_return("")
        File.stub!(:read).and_raise(StandardError.new)
        cluster_task.capture_job_out_err
        cluster_task.script_text.should be == ""
      end 

      
    end
    
  end

end

