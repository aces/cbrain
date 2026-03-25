#!/usr/bin/env ruby

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

# This rspec file tests the Boutiques framework on the Portal side.
# It uses a test (mock) application to do so.
# This set of tests does the following:
#   (1) Validates the JSON descriptor
#   (2) Tests that the local script behaviour is as expected
#   (3) Tests the generated portal task class (including the after_form method)
#
# The following should be done before testing
#   bundle exec rake db:test:prepare
#   rake db:seed RAILS_ENV=test
# Then run via: rspec spec/boutiques/boutiques_tester_spec.rb --colour


# Helper testing methods
require_relative 'test_helpers'

# Gain access to the rails environment
require 'rails_helper'
require 'spec_helper'

# Add helper methods for performing tests
include TestHelpers

# Run the Boutiques test on the BrainPortal side
describe "BrainPortal Boutiques Tests" do

  before(:all) do
    createInputFiles # Create required input files
    PWD = Dir.pwd # Save the starting dir form which the tests were launched
    @admin = User.admin
  end

  before(:each) do
    # Change to the temporary storage directory so files are automatically written there
    Dir.chdir TempStore
    # Build some of the cbrain environment
    @user, @group = FactoryBot.create(:user), FactoryBot.create(:group)
    @dp = FlatDirLocalDataProvider.new({
      :online => true, :read_only => false, :remote_dir => '.', :name => "dp1", :user_id => @admin.id, :group_id => @group.id
    })
    @dp.save!
    # Lambda for constructing cbcsv files
    @makeCbcsv = -> (fs, name, task, mangler=nil, addToUids=true, user: @user, group: @group, dp: @dp) {
      flist = CbrainFileList.new(
        :user             => user,
        :user_id          => user.id,
        :group_id         => group.id,
        :name             => name,
        :data_provider_id => dp.id,
      )
      flist.save
      text = CbrainFileList.create_csv_file_from_userfiles( fs )
      text = mangler.( text ) unless mangler.nil?
      flist.cache_writehandle { |t| t.write( text ) }
      task.params[:interface_userfile_ids] ||= []           if addToUids
      task.params[:interface_userfile_ids]  |= [ flist.id ] if addToUids
      flist # return the cbcsv object
    }
    # Helper for generating and sending userfiles to tasks
    @addUserFile = -> (name, task, addToUids=true, user: @user, group: @group, dp: @dp) {
      uf = SingleFile.new({data_provider_id: dp.id, name: name, group_id: group.id, user_id: user.id})
      uf.save!
      task.params[:interface_userfile_ids] ||= []        if addToUids
      task.params[:interface_userfile_ids]  |= [ uf.id ] if addToUids
      uf
    }
    # Checks after_form output. Checks both the number or errors and ascertains at least one of their contents.
    @checkAfterForm = -> (task, checkVal=0, atLeastOneErrWith=nil, runBeforeForm=false) {
      task.params_errors.clear
      task.before_form if runBeforeForm
      task.after_form # Run the method
      errMsgs = task.params_errors.full_messages # Get any error messages
      expect( errMsgs.any? { |e| e.include? atLeastOneErrWith } ).to be true unless atLeastOneErrWith.nil?
      expect( errMsgs.length ).to eq( checkVal )
    }
    # Function to manually add a null row to a cbcsv
    @nilRowAdder = -> (text) {
      fs, rt, n = CbrainFileList::FIELD_SEPARATOR, CbrainFileList::RECORD_TERMINATOR, CbrainFileList::ATTRIBUTES_LIST.length
      splitTxt  = text.split( rt )
      nilRow    = '0' + fs*(n - 1)
      splitTxt  << nilRow << ""
      splitTxt.join( rt )
    }
  end

  # Always need to move back to the original starting dir
  after(:each) do
    Dir.chdir PWD
  end

  # Post-test cleanup via after block
  after(:all) do
    destroyInputFiles
    destroyOutputFiles
  end

  # Validate correctness of JSON descriptor
  describe "JSON descriptor" do
    it "validates" do
      schemaLoc = File.join(Rails.root, "lib/boutiques.schema.json")
      expect( runAndCheckJsonValidator(schemaLoc) ).to eql(true)
    end
  end

  # Run tests locally on script
  describe "Local script test" do

    # The local script test needs to stay at the original start point
    before(:each) do
      Dir.chdir PWD
    end

    # After each local test, destroy the output files
    after(:each) do
      destroyOutputFiles
    end

    # Perform the local tests to make sure the program behaves as expected
    # (especially as it is changed to add new Boutiques features)
    BasicTests.each do |test|
      it "#{test[0]}" do
        expect( runTestScript( test[1], test[3] || [] ) ).to eq( test[2] )
      end
    end

  end

  # Run tests on generated portal tasks based on full mock app
  describe 'Local boutiques task (full mock app):' do

    # Run before block to create required task and task class
    before(:each) do
      # Create environment
      execer         = FactoryBot.create(:bourreau)
      schema         = Rails.root + "lib/boutiques.schema.json"
      desc_path      = File.join(__dir__, TestScriptDescriptor)
      @descriptor    = BoutiquesSupport::BoutiquesDescriptor.new_from_file(desc_path)

      tool           = Tool.create_from_descriptor(@descriptor)
      tool_config    = ToolConfig.create_from_descriptor(execer, tool, @descriptor)
      if ! BoutiquesTask.const_defined?(:BoutiquesTest)
        BoutiquesBootIntegrator.link_from_json_file(desc_path) rescue nil
      end

      # Instantiate a task object
      @task          = BoutiquesTask::BoutiquesTest.new
      @task.bourreau = execer
      @task.tool_config = FactoryBot.create(:tool_config)
      @task.user_id, @task.group_id, @task.params = @user.id, @group.id, {}.with_indifferent_access
      # Setup for holding the files the user had selected in the UI
      @task.params[:interface_userfile_ids] = []
      # Create userfiles for C, d, j, f (used to convert the ids from strings to numbers)
      @file_C, @file_d, @file_j = @addUserFile.('c',@task), @addUserFile.('d',@task), @addUserFile.('j',@task)
      @file_f1, @file_f2 = @addUserFile.('f1',@task), @addUserFile.('f2',@task)
      # Helper for converting files in the argument dict to int ids
      @replaceFileIds = -> (replaceF=false) {
        @task.invoke_params[:C] = @file_C.id unless @task.invoke_params[:C].nil?
        @task.invoke_params[:d] = @file_d.id unless @task.invoke_params[:d].nil?
        @task.invoke_params[:j] = @file_j.id unless @task.invoke_params[:j].nil?
        @task.invoke_params[:f] = [ @file_f1.id, @file_f2.id ] if replaceF
      }
      # Give access to the class version of the task
      @task_const = BoutiquesTask::BoutiquesTest
    end

    # Test the portal class automatically generated and registered in cbrain via the GeneratedTask Object
    context "Boutiques Generated Class Properties" do
      it "should have the right task class name" do
        expect( @task_const.to_s ).to eq( "BoutiquesTask::BoutiquesTest" )
      end
      it "should have a tool" do
        expect( Tool.exists?(:cbrain_task_class_name => @task_const.to_s) ).to be true
      end
      it "should have no public path" do # Just test the help file
        expect( @task_const.public_path("edit_params_help.html") ).to eq( nil )
      end
      it "has pretty param names" do
        @task_const.add_pretty_params_names(@descriptor.inputs || [])
        allThere = TestArgs.all? { |s| @task_const.pretty_params_names[@descriptor.input_by_id(s).cb_invoke_name] == s.to_s }
        expect( allThere ).to be true
      end
    end

    # Test an object instantiated from the portal class generated by the Boutiques framework
    context "Generated Portal Task" do
      # General properties of the Portal task class/object
      it "should have the right name" do
        expect( @task.name ).to eq( "BoutiquesTest" )
      end
      it "should have a bourreau" do
        expect( @task.bourreau ).not_to eq( nil )
      end
      it "should have a tool id" do
        expect( @task.tool.id  ).not_to eq( nil )
      end

      # The before_form method should fail if no UserFiles are given, but work otherwise
      # Here, UserFile existence is merely simulated, and before_form is tested in isolation
      describe "has a before_form method that" do
        before(:each) do
          @task.params = {}.with_indifferent_access
        end
        it "should fail when no input files are given" do
          expect { @task.before_form }.to raise_error(CbrainError, /This task requires/i)
        end
      end

      # Test the after_form method of the object
      # We run essentially the same test inputs as those sent to the local script, except
      # that we skip tests that check aspects that the isolated after_form cannot handle
      describe "has an after_form method that" do
        # after_form cannot check userfiles or flag existence (i.e. against the application) in this isolated test
        ignoredMsgs = ["invalid or missing userfile"]
        BasicTests.all? do |t|
          # Ignore tests requiring file existence checks (10 is an exit code for file existence check failure)
          # or tests that would need to check against the actual application (e.g. recognize argument existence).
          # The latter problem is excluded at a different level than after_form (since no input form will be created for it).
          next true if !t[3].nil? || t[2]==10 || t[0].include?("unrecognized")
          # Perform after_form test
          it "after_form #{t[0]}" do
            @task.params_errors.clear # Reset to having no errors
            begin # Parse the input command line
              @task.params[:invoke] = ArgumentDictionary.( t[1].dup ).with_indifferent_access
            rescue OptionParser::MissingArgument => e
              next # after_form does not need to check this, since rails puts a value in the hash
            end
            hasFileListFilled = ! @task.invoke_params[:f].nil? # Whether the file list parameter is in use
            @task.invoke_params[:f] ||= [] # after_form expects [], not nil, for empty file lists
            @replaceFileIds.( hasFileListFilled ) # replace the file paths with IDs
            @task.after_form # Run the method
            errMsgs = @task.params_errors.full_messages
            # Cannot check userfile existence and so on in this isolated test, so ignore those errors
            errMsgs.delete_if { |m| ignoredMsgs.any? { |e| m.include?(e) } }
            # When there is an error, the exit code should be non-zero; no errors should be present otherwise
            expect(
              if (errMsgs.length == 0 && t[2] == 0) || (errMsgs.length > 0 && t[2] != 0)
                true
              else
                # Uncomment this to debug a particularly tricky situation
                #puts_yellow "Got #{errMsgs.length} error messages and expected #{t[2]}"
                #puts_yellow "Messages are:\n#{errMsgs.join("\n")}" if errMsgs.length > 0
                #puts_yellow "Params: #{@task.params.inspect}"
                false
              end
            ).to be true
            @task.params = {}.with_indifferent_access # Clean up; @task is shared between tests
          end # it block
        end # all? block
      end # describe block generated after_form method

      # Test the portal task with respect to its behaviour when a user wishes to launch multiple jobs for a single task
      context "works with cbcsv files" do

        # Setup the environment with several userfiles and cbcsv files
        before(:each) do
          # Fill in the minimal required arguments for the class (but save the mock UI chosen files)
          @task.params_errors.clear
          @task.params[:invoke] = ArgumentDictionary.( MinArgs ).with_indifferent_access
          # Create some user files
          @userfiles   = (0..9).map { |i| @addUserFile.("f-#{i}",@task) }
          # Create some cbcsvs
          @std1, @std2 = @makeCbcsv.(@userfiles[0..3],"std2.cbcsv",@task), @makeCbcsv.(@userfiles[4..7],"std1.cbcsv",@task)
          # File input parameters
          @task.invoke_params[:C]   = @file_C.id # Replace as above, since it is a required argument
          @task.invoke_params[:f] ||= [] # after_form expects [], not nil, for empty file lists
        end

        # Clean up after each test by removing the cbcsvs we saved (includes destroying them on the data provider)
        after(:each) do
          Userfile.all.select { |f| f.is_a?(CbrainFileList) }.each { |uf| uf.destroy }
        end

        # Test the after_form error checking for multi-task launching
        describe "in after_form" do
          it "with one cbcsv file" do
            @task.invoke_params[:d] = @std1.id # single cbcsv
            @checkAfterForm.( @task )
          end
          it "with more than one cbcsv files" do
            @task.invoke_params[:d], @task.invoke_params[:j] = @std1.id, @std2.id
            @checkAfterForm.( @task )
          end
          it "with a cbcsv that does not have the cbcsv extension" do
            @task.invoke_params[:d] = @makeCbcsv.(@userfiles[0..3],"misname.m",@task).id
            @checkAfterForm.( @task )
          end
          it "with a cbcsv with nil entries" do
            nilEntries = @makeCbcsv.(@userfiles[3..6],"hasNils.cbcsv",@task,@nilRowAdder)
            @task.invoke_params[:d] = nilEntries.id
            @checkAfterForm.( @task )
          end
          it "to detect errors when lengths don't match" do
            smaller = @makeCbcsv.(@userfiles[8..9], "small.cbcsv", @task)
            @task.invoke_params[:d], @task.invoke_params[:j] = @std1.id, smaller.id
            @checkAfterForm.( @task, 1, "number of files" )
          end
          it "to detect errors when a file does not exist" do
            noFile = @makeCbcsv.(@userfiles[2..5], "missing.cbcsv", @task,
              -> (text) { # Lambda for mangling the input text so the first number becomes invalid (choose max + 1)
                v    = text.split( CbrainFileList::FIELD_SEPARATOR )
                v[0] = Userfile.all.map { |f| f.id }.max + 1
                v.join( CbrainFileList::FIELD_SEPARATOR )
              }
            )
            @task.invoke_params[:d] = noFile.id
            @checkAfterForm.( @task, 1, "unable to find file" )
          end
          it "to detect errors when a file is inaccessible" do
            # Create a new user and file for him/her
            user2, grp2 = FactoryBot.create( :user ), FactoryBot.create( :group )
            file2 = @addUserFile.("file2.c", @task, user: user2, group: grp2)
            # Put the file in a cbcsv and check after_form
            cbcsvTest = @makeCbcsv.([@userfiles[0],file2,@userfiles[1]],"cbcsvWithOthersFiles.cbcsv", @task)
            @task.invoke_params[:d] = cbcsvTest.id
            # Make sure after_form catches the problem
            @checkAfterForm.( @task, 1, "unable to find file" )
          end
          # This assumes the user made a mistake, e.g. forgot to convert the file, in this case
          it "to detect errors when a file is not a cbcsv but has the cbcsv extension" do
            @task.invoke_params[:d] = @addUserFile.('fake.cbcsv',@task).id
            @checkAfterForm.( @task, 1, "not of type" )
          end
          it "to detect errors when a row has invalid attributes" do
            invalidFile = @makeCbcsv.(@userfiles[3..7], "invalidRow.cbcsv",@task,
              -> (text) { # Lambda for mangling the input text so the first row, second col, becomes invalid
                v    = text.split( CbrainFileList::FIELD_SEPARATOR )
                v[1] = "wrongName.m"
                v.join( CbrainFileList::FIELD_SEPARATOR )
              }
            )
            @task.invoke_params[:d] = invalidFile.id
            @checkAfterForm.( @task, 1, "are invalid" ) # Two errors: as the misnamed file is missing and the row is invalid
          end
        end

        # Test the final_task_list method i.e. the actual generation of multiple jobs from the task
        # Note the special case where there is a single file-type input is tested below
        describe "in final_task_list" do
          # Normal case (no cbcsv files)
          it "with no cbcsvs" do
            @task.invoke_params[:C] = @userfiles[0].id
            expect( @task.final_task_list.length ).to eq( 1 )
          end
          # Standard single cbcsv case
          it "with a single cbcsv" do
            @task.invoke_params[:C] = @std1.id
            expect( @task.final_task_list.length ).to eq( 4 )
          end
          # The presence of null entries should give tasks with empty parameters when reached
          it "with nil entries in cbcsvs" do
            c1 = @makeCbcsv.(@userfiles[3..6],"hasNils.cbcsv",@task,@nilRowAdder)
            #c2 = @makeCbcsv.(@userfiles[1..5],"noNils.cbcsv",@task)
            @task.invoke_params[:C] = c1.id
            #@task.invoke_params[:j] = c2.id
            taskList = @task.final_task_list
            # Should be 5 tasks in total (the nil row should count)
            expect( taskList.length ).to eq( 4 )
            # Should be nothing for d when it's the nil row's turn
            taskList.each_with_index do |task, i|
              expect( task.invoke_params[:C] ).to eq( @userfiles[i+3].id )
              #expect( task.invoke_params[:j] ).to eq( @userfiles[i+1].id )
            end
          end
        end
      end

    end # Generated portal task context block
  end # Local boutiques task (full mock app) description

  # Run tests on the generated portal tasks derived from a minimal task object
  # Note: can read warnings via e.g. @task.getlog
  describe 'Local boutiques task (minimal app):' do

    # Run before block to create Minimal task, added to by specific tests
    before(:each) do
      # Generate a descriptor
      @descriptor    = BoutiquesSupport::BoutiquesDescriptor.new(NewMinimalTask.())
      execer         = FactoryBot.create(:bourreau)
      tool           = Tool.create_from_descriptor(@descriptor)
      tool_config    = ToolConfig.create_from_descriptor(execer, tool, @descriptor)
      BoutiquesTask.const_set(:MinimalTest, Class.new(BoutiquesPortalTask)) if ! BoutiquesTask.const_defined?(:MinimalTest)
      ToolConfig.register_descriptor(@descriptor, tool.name, tool_config.version_name) rescue nil

      # Generates a task object from the minimal mock app
key = [ tool.name, tool_config.version_name ]
      @generateTask = ->(params,reset_desc = nil) do
        useDefaults = (params.is_a? String) && (params == 'defaults')
        task = BoutiquesTask::MinimalTest.new(:tool_config_id => tool_config.id, :bourreau_id => execer.id)

        # reset_desc is a kludge
        if reset_desc
          ToolConfig.instance_eval {
            @_descriptors_[key] = reset_desc
          }
        end

        task.params = useDefaults ? task.default_launch_args : { :invoke => params.with_indifferent_access }
        task
      end
    end

    # Test the object generated by the Boutiques generator
    context "Boutiques GeneratedTask Object" do
      it "should have the right names" do
        expect( (BoutiquesTask::MinimalTest.new).name ).to eq( "MinimalTest" ) # Check for task instance
      end
    end

    # Test special case for cbcsv files when there is only one (required) file-type input
    context "cbcsv single-file special case" do
      # Setup user, userfile, and cbcsv creation as in the full mock app case
      before(:each) do
        # Modify descriptor to take in more file-type inputs
        @descriptor['command-line'] += '[F] '
        @descriptor['inputs'] << GenerateJsonInputDefault.("f", 'File', 'File arg')
        # Instantiate a task object from the descriptor
        @task = @generateTask.( 'defaults', @descriptor )
        # Add metadata to the task
        @task.bourreau = FactoryBot.create(:bourreau)
        @task.user_id, @task.group_id, @task.params = @user.id, @group.id, {}.with_indifferent_access
        @task.params[:interface_userfile_ids] = []
        @task.tool_config = FactoryBot.create(:tool_config)
        # Generate some userfiles for testing
        @f1, @f2, @f3 = @addUserFile.('f1.cpp',@task,false), @addUserFile.('f2.java',@task,false), @addUserFile.('f3.j',@task,false)
      end
      # Clean up after each test by removing the cbcsvs we saved (includes destroying them on the data provider)
      after(:each) do
        Userfile.all.select { |f| f.is_a?(CbrainFileList) }.each { |uf| uf.destroy }
      end
      describe "has after_form that" do
        it "works with one cbcsv" do
          cb1 = @makeCbcsv.([@f1,@f2], 'test.cbcsv', @task)
          @task.invoke_params['f'] = cb1.id
          @checkAfterForm.( @task, 0, nil, true )
        end
        #it "works with two cbcsvs" do
        #  @makeCbcsv.([@f1,@f2], 't1.cbcsv', @task); @makeCbcsv.([@f1,@f3], 't2.cbcsv', @task)
        #  @checkAfterForm.( @task, 0, nil, true )
        #end
        #it "works with two cbcsvs of different lengths" do
        #  @makeCbcsv.([@f1,@f2], 't1.cbcsv', @task); @makeCbcsv.([@f1,@f2,@f3], 't2.cbcsv', @task)
        #  @checkAfterForm.( @task, 0, nil, true )
        #end
        it "fails when a subfile is non-existent" do
          cbl = @makeCbcsv.( [@f1,@f2,@f3], 'missing.cbcsv', @task,
            -> (text) { # Lambda for mangling the input text so the first number becomes invalid (choose max + 1)
              v    = text.split( CbrainFileList::FIELD_SEPARATOR )
              v[0] = Userfile.pluck(:id).max + 1
              v.join( CbrainFileList::FIELD_SEPARATOR )
            }
          )
          @task.invoke_params['f'] = cbl.id
          @checkAfterForm.( @task, 1, "unable to find file", true )
        end
        it "fails gracefully when a file is inaccessible" do
          # Create a new user and file for him/her
          user2, grp2 = FactoryBot.create( :user ), FactoryBot.create( :group )
          file2 = @addUserFile.("f2.tex", @task, user: user2, group: grp2)
          # Make sure after_form catches the problem
          @task.invoke_params['f'] = file2.id
          @checkAfterForm.( @task, 1, "cannot find userfile", true )
        end
        it "fails gracefully when a cbcsv subfile is inaccessible" do
          # Create a new user and file for him/her
          user2, grp2 = FactoryBot.create( :user ), FactoryBot.create( :group )
          file2 = @addUserFile.("f2.swift", @task, false, user: user2, group: grp2)
          # Put the file in a cbcsv and check after_form (only add the prohibited file to a cbcsv)
          cbcsvTest = @makeCbcsv.( [@f1,file2,@f3], "cbcsvWithOthersFiles.cbcsv", @task)
          # Make sure after_form catches the problem
          @task.invoke_params['f'] = cbcsvTest.id
          @checkAfterForm.( @task, 1, "unable to find file", true )
        end
        it "fails when there are non-matching attributes" do
          # Create an invalid file
          invalidFile = @makeCbcsv.( [@f1,@f2,@f3], "invalidRow.cbcsv", @task,
            -> (text) { # Lambda for mangling the input text so the first row, second col, becomes invalid
              v    = text.split( CbrainFileList::FIELD_SEPARATOR )
              v[1] = "wrongName.m"
              v.join( CbrainFileList::FIELD_SEPARATOR )
            }
          )
          @task.invoke_params['f'] = invalidFile.id
          @checkAfterForm.( @task, 1, "are invalid" )
        end
      end
      describe "has final_task_list that" do
        it "works with no cbcsvs" do
          @addUserFile.('t.txt',@task); @addUserFile.('r.txt',@task)
          expect( @task.final_task_list.length ).to eq( 2 )
        end
        it "works with one cbcsv" do
          @makeCbcsv.([@f1,@f2,@f3], 'test.cbcsv', @task)
          expect( @task.final_task_list.length ).to eq( 3 )
        end
        it "works with multiple cbcsvs" do
          @makeCbcsv.([@f1,@f2], 't1.cbcsv', @task); @makeCbcsv.([@f1,@f2,@f3], 't2.cbcsv', @task)
          expect( @task.final_task_list.length ).to eq( 5 )
        end
        it "works with a mixture of cbcsvs and normal files" do
          @addUserFile.('t.txt',@task); @addUserFile.('r.txt',@task)
          @makeCbcsv.([@f1,@f2], 't1.cbcsv', @task); @makeCbcsv.([@f1,@f2,@f3], 't2.cbcsv', @task)
          expect( @task.final_task_list.length ).to eq( 7 )
        end
        it "works with null cbcsv entries" do
          @addUserFile.('t.ada', @task)
          @makeCbcsv.([@f1,@f2,@f3], "hasNils.cbcsv", @task, @nilRowAdder)
          expect( @task.final_task_list.length ).to eq( 4 ) # i.e. the null entry should be ignored
        end
      end # describe task launch
    end # context single-file special case

    # Default-values work appropriately
    context 'Default values' do
      before(:each) do
        @descriptor['command-line'] += '[B] '
      end
      it "should work a regular type" do
        @descriptor['inputs'] << GenerateJsonInputDefault.('b','Number','A number arg',{'default-value' => 9})
        task = @generateTask.( 'defaults', @descriptor )
        task.before_form
        @checkAfterForm.( task )
      end
      it "should work with appropriate enums" do
        @descriptor['inputs'] << GenerateJsonInputDefault.('b','String','An enum arg',{'value-choices' => ['a','b','c'], 'default-value' => 'b'})
        task = @generateTask.( 'defaults', @descriptor )
        task.before_form
        @checkAfterForm.( task )
      end
      it "should fail with an inappropriate enum value" do
        @descriptor['inputs'] << GenerateJsonInputDefault.('b','String','An enum arg',{'value-choices' => ['a','b','c'], 'default-value' => 'd'})
        task = @generateTask.( 'defaults', @descriptor )
        task.before_form
        @checkAfterForm.( task, 1, "acceptable value" ) # Should give an error relating to the enum having an unacceptable value
      end
    end

    # Ensure that disables/requires and groups are independent
    # In response to an after_form bug where generated group code relied on disables/requires code
    context "groups and disables/requires independence in after_form" do

      before(:each) do
        @descriptor['inputs'] << GenerateJsonInputDefault.('b','Number','A number arg')
        @descriptor['command-line'] += '[B] '
      end

      it "is satisfied when neither is present" do
        task = @generateTask.( { a: 'val' , b: '1'}, @descriptor )
        @checkAfterForm.( task )
      end
      it "is satisfied when only groups are present" do
        @descriptor['groups'] = [BoutiquesSupport::Group.new({'id' => 'G', 'name' => 'G', 'members' => ['a','b'], 'mutually-exclusive' => true})]
        task = @generateTask.( { a: 'val1' }, @descriptor )
        @checkAfterForm.( task )
      end
      it "is satisfied when only disables is present" do
        @descriptor['inputs'][0]['disables-inputs'] = ['b']
        task = @generateTask.( { a: 'val1' }, @descriptor )
        @checkAfterForm.( task )
      end
      it "is satisfied when only requires is present" do
        @descriptor['inputs'][0]['requires-inputs'] = ['b']
        task = @generateTask.( { a: 'val1', b: 9 }, @descriptor )
        @checkAfterForm.( task )
      end
    end # after_form independence

  end # Minimal app context

end # Portal side tests

