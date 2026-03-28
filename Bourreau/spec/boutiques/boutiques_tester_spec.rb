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

# Bourreau-side tests for the Boutiques framework, using a mock tool (boutiquesTestApp.rb).
# Tests the generated cluster task by using it to create cluster commands that test against
# the mock tool and its expected output for each set of input parameters.
#
# Running the tests requires running (on the BrainPortal side):
#   bundle exec rake db:test:prepare
#   rake db:seed RAILS_ENV=test
#   RAILS_ENV=test rake db:seed:test:bourreau
# Then run via: rspec spec/boutiques/boutiques_tester_spec.rb --colour

# Required files for inclusion
require 'rails_helper'
require 'spec_helper'
require_relative 'test_helpers'

# Add helper methods for performing tests
include TestHelpers

# Testing the Boutiques framework on the Bourreau side
describe "Bourreau Boutiques Tests" do

  # Run before block to create required input files
  before(:all) do
        Userfile.all.each{ |uf| uf.destroy }
        DataProvider.all.each { |dp| dp.destroy }
    # The group, provider, and user ids used downstream
    GID, UID, DPID = Group.everyone.id, User.admin.id, 9
    @ftype = lambda { |fname| Userfile.suggested_file_type(fname) || SingleFile }

    @execer        = RemoteResource.current_resource
    # Get the schema and json descriptor
    desc_path      = File.join(__dir__, TestScriptDescriptor)
    @descriptor    = BoutiquesSupport::BoutiquesDescriptor.new_from_file(desc_path)

    @unrestricted_descriptor = @descriptor.dup
    @unrestricted_descriptor.inputs.each { |input| input.optional = true; input.delete "requires-inputs" ; input.delete "disables-inputs" }
    @unrestricted_descriptor.groups.each { |group| group.delete "mutually-exclusive" ; group.delete "one-is-required" }

    # Create tool and tool config and task class
    tool           = Tool.create_from_descriptor(@descriptor)
    @tool_config   = ToolConfig.create_from_descriptor(@execer, tool, @descriptor)
    if ! BoutiquesTask.const_defined?(:BoutiquesTest)
      BoutiquesBootIntegrator.link_from_json_file(desc_path) rescue nil
    end
    key = [ tool.name, @tool_config.version_name ]
    @switchDescriptor = ->(desc) {
      ToolConfig.instance_eval { @_descriptors_[key] = desc.dup }
    }
    @switchDescriptor.(@descriptor) # resets to full standard
    # Create new data provider
    @provider    = FlatDirLocalDataProvider.new({ :online => true, :read_only => false, :remote_dir => '.' })
    @provider.id, @provider.name, @provider.user_id, @provider.group_id = DPID, 'test_provider', UID, GID
    @provider.save!
    @userFiles   = InputFilesList.map { |f| uf=Userfile.new(:type => @ftype.(f), name: File.basename(f), data_provider_id: DPID, user_id: UID, group_id: GID); uf.save!; uf }

    @minimalDescriptor = NewMinimalTask.()
    min_tool         = Tool.create_from_descriptor(@minimalDescriptor)
    @min_tool_config = ToolConfig.create_from_descriptor(@execer, min_tool, @minimalDescriptor)
    if ! BoutiquesTask.const_defined?(:MinimalTask)
      BoutiquesBootIntegrator.link_from_descriptor(@minimalDescriptor) rescue nil
    end

    # Adjust numbers; tries to guess what they should
    # be. We leave bad values alone (e.g. bad strings) for tests
    @adjustNumbers = ->(task) do
      task.boutiques_descriptor.inputs
        .select { |input| input.type == 'Number' }
        .each do |input|
          val = task.invoke_params[input.id]
          next if val.blank?
          if val.is_a?(String) && val =~ /\A-?[0-9.]+\z/
            val = (input.integer ? Integer(val) : Float(val)) rescue val
            task.invoke_params[input.id] = val
          elsif val.is_a?(Array)
            val = val.map do |x|
              next x if x !~ /\A-?[0-9.]+\z/
              (input.integer ? Integer(x) : Float(x)) rescue x
            end
            task.invoke_params[input.id] = val
          end
        end
    end
  end

  # Post-test cleanup via after block
  after(:all) do
    Dir.chdir(TempStore) do
      destroyInputFiles
      destroyOutputFiles
    end
  end

  context "Cbrain external" do
    # Run before block to create ClusterTask object
    before(:each) do
      # Create a new instance of the generated task class
      @task             = BoutiquesTask::BoutiquesTest.new
      @task.cluster_workdir = 'fcw'
      @task.tool_config_id = @tool_config.id
      @task.params          = {}.with_indifferent_access
      @task.params[:invoke] = {}.with_indifferent_access
      # Assign it a bourreau
      resource = RemoteResource.current_resource
      @task.bourreau_id = resource.id
      # Give access to the generated task class itself
      @task_const = BoutiquesTask::BoutiquesTest
    end

    before(:all) do
      Dir.chdir(TempStore) do
        createInputFiles
      end
    end

    # Tests expected behaviour of the auto-generated cluster task
    describe "Generated ClusterTask Object" do

      # Check necessary properties of the descriptor object
      describe "descriptor" do
        it "has the right name" do
          expect( @task.boutiques_descriptor.name ).to eq( 'BoutiquesTest' )
        end
      end

      # Test some basic properties
      it "creates a tool" do
        expect( Tool.exists?( :cbrain_task_class_name => @task_const.to_s ) ).to be true
      end

      it "makes the tool accessible as a Cbrain Task object" do
        expect( @task_const.tool ).not_to be_nil
      end

      # Test that creating a basic cluster command in isolation works
      it "can create cluster commands" do
        @switchDescriptor.(@unrestricted_descriptor)
        @task.invoke_params[:A] = "A_VAL"
        expect( NormedTaskCmd.(@task) ).to eq( './' + TestScriptName + ' -A A_VAL -r r.txt' )
      end

      # Test that creating cluster commands with string lists works
      it "can create cluster commands with lists" do
        @task.invoke_params[:A] = "A_VAL"
        @task.invoke_params[:p] = ['e1', 'e2', 'e3']
        expect( NormedTaskCmd.(@task) ).to eq( './' + TestScriptName + ' -A A_VAL -p e1 e2 e3 -r r.txt' )
      end

      # Test that export commands work and are in the right place
      it "exports environment variables" do
        @switchDescriptor.(@unrestricted_descriptor)
        expect( @task.cluster_commands.join('') ).to include("export ev1=nice_value\n")
      end

      # It properly escapes environment variables
      # Note that we only have to worry about inappropriate values that are still valid JSON
      it "escapes environment variables" do
        @switchDescriptor.(@unrestricted_descriptor)
        expect( @task.cluster_commands.join('') ).to include("export ev2='ta- 9\"\\'\\''_%^&$@]['")
      end

    end

    # Test cluster_commands generation for a minimal mock app
    context 'Minimal Mock App' do

      # Bourreau-side generation of minimal task
      before(:each) do
        # Generate a descriptor
        @descriptor = NewMinimalTask.()
        # Generates a task object from the minimal mock app
        @generateTask = -> (params) {
          task = BoutiquesTask::MinimalTest.new(:tool_config_id => @min_tool_config.id, :bourreau_id => @execer.id)
          task.cluster_workdir = "task_wd"
          task.params = {}.with_indifferent_access
          task.params[:invoke] = params.with_indifferent_access
          key = [ @min_tool_config.tool.name, @min_tool_config.version_name ]
          desc = @descriptor
          ToolConfig.instance_eval { @_descriptors_[key] = desc }
          task
        }
      end

      context 'cluster_command substitution' do

        # Test basic command substitution correctness
        it "should correctly substitute cluster_commands with default settings" do
          task = @generateTask.( { a: 'value' } )
          expect( task.cluster_commands[0].strip ).to include( "/minimalApp -a value\n" )
        end

        # Test output flag substitution
        it "should correctly substitute cluster_commands with output keys" do
          @descriptor['command-line'] += ' [OUT-KEY]'
          @descriptor['output-files'][0].merge!( { 'value-key' => '[OUT-KEY]', 'command-line-flag' => '-o' } )
          task = @generateTask.( { a: 'value' } )
          expect( task.cluster_commands[0].strip ).to include( "/minimalApp -a value -o value" )
        end

        # Test output flag separator substitution
        it "should correctly substitute cluster_commands with output keys and a separator" do
          @descriptor['command-line'] += ' [OUT-KEY]'
          @descriptor['output-files'][0].merge!( {
            'value-key'                   => '[OUT-KEY]',
            'command-line-flag'           => '-o',
            'command-line-flag-separator' => '=' } )
          task = @generateTask.( { a: 'value' } )
          expect( task.cluster_commands[0].strip ).to include( "/minimalApp -a value -o=value" )
        end

        # Test output flag separator substitution with prior path-template substitution
        it "should correctly substitute cluster_commands with output flag separators and path-template substitutions" do
          @descriptor['command-line'] += ' [B] [OUT-KEY]'
          @descriptor['inputs'] << GenerateJsonInputDefault.('b','Number','Numerical arg')
          @descriptor['output-files'][0].merge!( {
            'value-key'                   => '[OUT-KEY]',
            'command-line-flag'           => '-o',
            'path-template'               => '[A]+[B]',
            'command-line-flag-separator' => '/' } )
          task = @generateTask.( { a: 'val', b: 9 } )
          expect( task.cluster_commands[0].strip ).to include( "/minimalApp -a val -b 9 -o/val+9" )
        end

        # Test absolute file path
        it "should correctly generate full paths if uses-absolute-path is set" do
          @descriptor['command-line'] += ' [F1] [F2]'
          @descriptor['inputs'] << GenerateJsonInputDefault.('f1','File','basename file', { 'uses-absolute-path' => false } )
          @descriptor['inputs'] << GenerateJsonInputDefault.('f2','File','abs path file', { 'uses-absolute-path' => true } )
          task = @generateTask.( { f1: Userfile.first.id , f2: Userfile.first.id } )
          expect( task.cluster_commands[0].strip ).to match( /minimalApp -f1 ([a-zA-Z0-9\.]+) -f2 \/.*\/\1/ )
        end

      end

    end

    # Testing Boutiques via the mock 'submission' of a local script, using the output of cluster_commands
    context 'Cluster Command Generation with Mock Program' do

      # The cluster_commands method requires userfiles to exist before running now
      before(:each) do
        # Clean userfiles and data providers
        #Userfile.all.each{ |uf| uf.destroy }
        #DataProvider.all.each { |dp| dp.destroy }
        # Create new data provider
        #@provider    = FlatDirLocalDataProvider.new({ :online => true, :read_only => false, :remote_dir => '.' })
        #@provider.id, @provider.name, @provider.user_id, @provider.group_id = DPID, 'test_provider', UID, GID
        #@provider.save!
        # Generate files used downstream
        @userFiles   = InputFilesList.map { |f| @task.safe_userfile_find_or_new(@ftype.(f), name: File.basename(f), data_provider_id: DPID, user_id: UID, group_id: GID) }
        @userFiles.each { |f| f.save! }
        @idsForFiles = @userFiles.map { |f| f.id }
        @switchDescriptor.(@descriptor) # resets to full standard
        Dir.chdir(TempStore) do
          destroyTaskSupportFiles
        end
      end

      # After each local test, destroy the output files, so they don't interfere with downstream tests
      after(:each) do
        Dir.chdir(TempStore) do
          destroyOutputFiles
          destroyTaskSupportFiles
        end
      end

      # Check that userfiles are discoverable
      it "interfaces with userfile system" do
        expect( @idsForFiles.all? { |t| Userfile.find_by_id( t ) } ).to be true
      end

      # Ensure that the `setup` method does not replace ids with hashes
      it "works with ids rather than objects" do
        @task.params[:invoke] = ArgumentDictionary.( "-A a -B 9 -C #{C_file} -v s -n 7 ", @idsForFiles )
        @task.cluster_workdir = 'fcw'
        @task.setup
        expect( @task.invoke_params[:C] ).to eq( @idsForFiles[0] )
      end

      # Perform tests by running the cmd line given by cluster_commands and checking the exit code
      BasicTests.each do |test|
        test_name    = test[0]
#next unless test_name == "fails when a required argument is missing (A: flag + value)"
        test_args    = test[1]
        test_status  = test[2]
        test_fnames  = test[3] || []
        test_cberror = test[4] # message in exception when the failure is in cluster_commands
        # Testing for unrecognized inputs will not work here, since apply_template will ignore them
        next if test_name.include?( "unrecognized" )
        # The apply_template method adds the separator on its own, so we need only check that works
        next if test_name.include?( "fails when special separator" )
        # Run the test
        it "#{test_name}" do
          Dir.chdir(TempStore) do
          # Mock the location of the full cluster workdir
          allow_any_instance_of( BoutiquesTask::BoutiquesTest ).to receive( :full_cluster_workdir ).and_return( File.join(Dir.pwd, TempStore) )
          begin # Convert string arg to params dict
            @task.params[:invoke] = ArgumentDictionary.( test_args, @idsForFiles )
            @adjustNumbers.(@task)
          rescue OptionParser::MissingArgument => e
            next # after_form does not need to check this here, since rails puts a value in the hash
          end
          # Run the generated command line from cluster_commands (-2 to ignore export lines and the echo log at -1)
          if test_cberror.present?
            expect { @task.cluster_commands }.to raise_error(Regexp.new(test_cberror))
          else
            opts = extractOptions( @task.cluster_commands.join(""), TestScriptName )
            exit_code = runTestScript(
              FileNamesToPaths.(
               #@task.cluster_commands.join("").strip.gsub('./'+TestScriptName,'')
               opts
              ), test_fnames )
            # Check that the exit code is appropriate
            expect( exit_code ).to eq( test_status )
          end
          end # chdir
        end
      end

    end
  end

  # Tests requiring complete Cbrain Bourreau-side system functionality
  describe 'Cbrain Internal' do

    # Define some useful constants (constants get redefined in before(:each) blocks)
    before(:all) do
      # The warning message used when unable to find optional output files
      OptOutFileNotFoundWarning = "Skipped optional missing output file"
      # Current rails pwd
      PWD = Dir.pwd
    end

    # Note: FactoryGirl methods should be used instead, but only if their db changes get rolled back in the before(:each) block
    # This is currently not happening, possibly due to some versioning issues
    before(:each) do
      Dir.chdir TempStore
      # Destroy any pre-existing userfiles
      Userfile.all.each{ |uf| uf.destroy }
      # Create a mock task required output file
      @fname           = DefReqOutName
      @fname_base      = File.basename(@fname) # Need because we will have to change to the temp dir
      FileUtils.touch(@fname)
      # Use helper method for getting filetype classes
      @userfileClass   = @ftype.(@fname)
      # Get the schema and json descriptor
      descriptor       = @descriptor.dup
      # Instantiate an object of the new class type
      @task            = BoutiquesTask::BoutiquesTest.new
      @task.tool_config_id = @tool_config.id
      @task.bourreau_id    = @tool_config.bourreau_id
      # Destroy any prior existing data providers (so we use a clean, lone one)
      DataProvider.all.each { |dp| dp.destroy }
      # Create a local data_provider to hold our files
      @provider        = FlatDirLocalDataProvider.new({ :online => true, :read_only => false, :remote_dir => '.' })
      @provider.id, @provider.name, @provider.user_id, @provider.group_id = DPID, 'test_provider', UID, GID
      @provider.save!
      @task.results_data_provider_id = @provider.id
      # Change base directory so checks for simulated files go to the right temp storage place
      # This is because some checks by e.g. save_results expect files from the task to be in the pwd
      # Passing a block to chdir would be preferable but then one would have to do it in every test
      allow( @task ).to receive( :full_cluster_workdir ).and_return( Dir.pwd )
      # Add a local input file to the data provider (allows smarter lookup in userfile_exists)
      @file_c, @ft     = 'c', @ftype.(@file_c)
      newFile          = @task.safe_userfile_find_or_new(@ft, name: @file_c, data_provider_id: DPID, user_id: UID, group_id: GID)
      newFile.save!
      # Fill in data necessary for the task to check for and save the output file '@fname'
      @task.params ||= { :interface_userfile_ids => [Userfile.all.first.id] }.with_indifferent_access
      @task.params[:invoke] = {}.with_indifferent_access
      @task.params[:invoke].merge!({:r => @fname_base })
      @task.user_id, @task.group_id = UID, GID
      # Generate a simulated exit file, as if the task had run
      @simExitFile     = @task.exit_status_filename
      File.write( @simExitFile, "0\n" )
      # The basic properties for the required output file
      @reqOutfileProps = {:name => @fname_base, :data_provider_id => @provider.id}
      # Optional output file properties
      @optOutFileName  = File.basename(OptOutName) # Implicitly in temp storage
      @optFileClass    = @ftype.( @optOutFileName )
      @switchDescriptor.(@unrestricted_descriptor)
    end

    # Clean up after each test
    after(:each) do
      # Also need to get rid of the (simulated) exit file
      File.delete( @simExitFile ) if @simExitFile.present? && File.exists?( @simExitFile )
      # Destroy the registered userfiles and the data_provider, so as not to affect downstream tests
      # Needed to destroy actual output files written to the filesystem
      Userfile.all.each{ |uf| uf.destroy }
      # Delete any generated output files
      destroyOutputFiles
      destroyTaskSupportFiles
      # Return to rails base dir
      Dir.chdir PWD
    end

    # Test that the generated Boutiques task can handle output file saving and renaming
    # Mostly tests the autogenerated save_results method of the mock Boutiques task
    context 'Output File Handling' do

      # Check that the input file could be properly registered
      it "has access to the registered input file" do
        expect( @task.userfile_exists( @ft, {:name => @file_c, :data_provider_id => @provider.id}) ).to be true
      end

      # Check that save_results properly verifies the exit code file (3 tests)
      it "save_results is false if the exit status file is missing" do
        File.delete(@simExitFile)
        expect( @task.save_results ).to be false
      end
      it "save_results raises an exception if the exit status file has invalid content" do
        File.write( @simExitFile, "abcde\n" )
        expect { @task.save_results }.to raise_error(/Exit status file.*has unexpected content/)
      end
      it "save_results is false if the exit status file contains a value greater than 1" do
        File.write( @simExitFile, "3\n" )
        expect( @task.save_results ).to be false
      end

      # Check that save_results works as expected for existent files
      it "can save results files" do
        # Make sure the file on the filesystem exists
        expect( File.exists?(@fname_base) ).to be true
        # Ensure the file has not been registered/created yet
        expect( @task.userfile_exists(@userfileClass, @reqOutfileProps) ).to be false
        # Ensure that saving the results occurs error-free
        @task.cluster_commands
        expect( @task.save_results ).to be true
        # Ensure that the file now exists in the data_provider
        # Output name now contains the run_id inside it...
        newname = "r-#{@task.run_id}.txt"
        expect( @task.userfile_exists(@userfileClass, { :name => newname, :data_provider_id => @provider.id}) ).to be true
      end

      # Check that, when a required output file is not present, the task fails gracefully
      it "fails non-catastrophically when a required output file is not there" do
        # The output file should exist
        expect( File.exists? @fname_base ).to be true
        # Destroy the required output file
        File.delete( @fname_base )
        # Attempting to save_results should return a 'failure' error code
        @task.cluster_commands
        expect( @task.save_results ).to be false
      end

      # Check that optional output files are saved appropriately
      it "handles optional output files when present" do
        # Create the optional output file
        FileUtils.touch( @optOutFileName )
        # Inform the generated task to look for the optional output file
        @task.params[:invoke] = @task.invoke_params.merge!({:o => @optOutFileName})
        # Ensure the file exists
        expect( File.exists? @optOutFileName ).to be true
        # Attempt to save both the optional and required output files. Should succeed.
        @task.cluster_commands
        expect( @task.save_results ).to be true
        # Both files should exist in the data_provider
        newReqName = "r-#{@task.run_id}.txt"
        newOptName = "o-#{@task.run_id}.txt"
        expect( @task.userfile_exists(@userfileClass, {:name => newReqName, :data_provider_id => @provider.id}) ).to be true
        expect( @task.userfile_exists(@optFileClass,  {:name => newOptName, :data_provider_id => @provider.id}) ).to be true
        # The log should not have warned about being unable to find the optional output file
        expect( @task.getlog.include?( OptOutFileNotFoundWarning ) ).to be false
      end

      # Check that there is no error when specified optional output files are not found
      # However, a logging should occur to note that fact
      it "handles absent optional output files properly" do
        # Inform the generated task to look for the optional output file
        @task.params[:invoke] = @task.invoke_params.merge!({:o => @optOutFileName})
        @switchDescriptor.(@unrestricted_descriptor) # resets to full standard
        # Ensure the file does not exist
        expect( File.exists? @optOutFileName ).to be false
        # Attempt to save both the optional and required output files. Should succeed (in terms of return value).
        @task.cluster_commands
        expect( @task.save_results ).to be true
        # Only the required file should exist in the data_provider
        newReqName = "r-#{@task.run_id}.txt"
        newOptName = "o-#{@task.run_id}.txt"
        expect( @task.userfile_exists(@userfileClass, {:name => newReqName, :data_provider_id => @provider.id}) ).to be true
        expect( @task.userfile_exists(@optFileClass,  {:name => newOptName, :data_provider_id => @provider.id}) ).to be false
        # Check that a notice was logged to warn of the missing optional output file
        expect( @task.getlog ).to include( OptOutFileNotFoundWarning )
      end

      # Ensure the files do not survive between tests
      it 'should destroy results files between tests' do
        expect( @task.userfile_exists(@userfileClass, @reqOutfileProps) ).to be false
      end

    end # End output file handling tests

  end

end

