#
# Bourreau-side tests for the Boutiques framework, using a mock tool (boutiquesTestApp.rb).
# Tests the generated cluster task by using it to create cluster commands that test against
# the mock tool and its expected output for each set of input parameters.
#

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
    FileUtils.touch('c')  # For -C
    FileUtils.touch('f')  # For -d
    FileUtils.touch('jf') # For -j
    [1,2].each { |i| FileUtils.touch("f#{i}") } # For -f
  end

  # Post-test cleanup via after block
  after(:all) do
    # Delete the input and output files when they exist
    ['c','f','jf','f1','f2'].each{ |f| File.delete(f) if File.exist?(f) }
    PotenOutFiles.each { |f| File.delete(f) if File.exist?(f) }
  end

  context "Cbrain external" do
    # Run before block to create ClusterTask object
    before(:each) do
      # Get the schema and json descriptor
      schema         = SchemaTaskGenerator.default_schema
      descriptor     = File.join(__dir__, 'descriptor_test.json')
      # Generate a new task class via the Boutiques framework and integrate it into cbrain
      @boutiquesTask = SchemaTaskGenerator.generate(schema, descriptor)
      @boutiquesTask.integrate if File.exists?(descriptor)
      # Create a new instance of the generated task class
      @task        = CbrainTask::BoutiquesTest.new
      @task.params = {}
      # Give access to the generated task class itself
      @task_const = "CbrainTask::#{SchemaTaskGenerator.classify(@task.name)}".constantize
    end

    # Tests expected behaviour of the auto-generated cluster task
    describe "Generated ClusterTask Object" do
     
      # Test some basic properties
      describe "descriptor" do
        it "has the right name" do
          expect( @boutiquesTask.descriptor['name'] ).to eq( 'BoutiquesTest' )
        end
      end

      it "creates a tool" do
        expect( Tool.exists?( :cbrain_task_class => @task_const.to_s ) ).to be true
      end
      it "makes the tool accessible" do
        expect( @task_const.tool ).not_to be_nil
      end

      # Test that the apply_template method works as expected
      # for some representative (or previously buggy) cases
      describe "apply_template" do

        # Define some default parameters to use in the tests
        before(:each) do
          @template = 'cmd [1] [2] [3] [4] [5]'
          @def_keys = {'[1]' => 'one.txt', '[2]' => 2,             '[3]' => 't.csv', '[4]' => nil, '[5]' => nil} 
          @flags    = {'[1]' => '-1',      '[2]' => '--long-flag', '[3]' => '-t',    '[4]' => nil, '[5]' => nil}
          @seps     = {'[1]' => '=',       '[2]' => '~',           '[3]' => ' ',     '[4]' => nil, '[5]' => nil}  
        end
        
        it "handles string substitutions" do  
          s = @task.apply_template(@template, @def_keys)
          expect( s.strip ).to eq( 'cmd one.txt 2 t.csv' )
        end

        it "handles string substituions with spaces" do
          s = @task.apply_template(@template, @def_keys.merge({'[4]' => '4 4'}))
          expect( s.strip ).to eq( "cmd one.txt 2 t.csv '4 4'" )
        end

        # Characters special to the shell or ruby's gsub should not interfere
        # In this case, ensure that ' is escaped properly
        it "handles special meaning characters" do
          s = @task.apply_template(@template, @def_keys.merge({'[4]' => " '; arg"}))
          expect( s.strip ).to eq( "cmd one.txt 2 t.csv ' '\\''; arg'" )
        end

        it "handles substitutions with command-line flags" do
          s = @task.apply_template(@template, @def_keys, flags: @flags)
          expect( s.strip ).to eq( "cmd -1 one.txt --long-flag 2 -t t.csv" )
        end

        it "handles substitution with flag-type inputs" do
          s = @task.apply_template(@template, @def_keys.merge({'[4]' => true}), flags: {'[4]' => '-f'})
          expect( s.strip ).to eq( "cmd one.txt 2 t.csv -f" )
        end

        it "handles special flag separator substitution" do
          s = @task.apply_template(@template, 
                @def_keys.merge({'[4]' => true}), 
                flags:      @flags.merge({'[4]' => '-f'}),
                separators: @seps)
          expect( s.strip ).to eq( "cmd -1=one.txt --long-flag~2 -t t.csv -f" )
        end

        it "properly strips endings" do
          s = @task.apply_template(@template,  
                @def_keys.merge({'[4]' => true, '[5]' => '9.tex'}),
                flags:      @flags.merge({'[4]' => '-f', '[5]' => '-tex'}),
                separators: @seps, 
                strip:      [ '.txt', '.tex' ])
          expect( s.strip ).to eq( "cmd -1=one --long-flag~2 -t t.csv -f -tex 9" )
        end

      end
      
      # Test that creating a basic cluster command in isolation works
      it "can create cluster commands" do        
        @task.params[:A] = "A_VAL"
        expect( @task.cluster_commands[0].strip ).to eq( './' + TestScriptName + ' -A A_VAL' )
      end
      
    end

    # Testing Boutiques via the mock 'submission' of a local script, using the output of cluster_commands
    context 'Cluster Command Generation with Mock Program' do
      
      # After each local test, destroy the output files, so they don't interfere with downstream tests
      after(:each) do
        destroyOutputFiles
      end

      # Perform tests by running the cmd line given by cluster_commands and checking the exit code
      BasicTests.each do |test|
        # Testing for unrecognized inputs will not work here, since apply_template will ignore them
        next if test[0].include?( "unrecognized" )
        # The apply_template method adds the separator on its own, so we need only check that works
        next if test[0].include?( "fails when special separator" )
        # Run the test
        it "#{test[0]}" do
          # Convert string argument to params dict
          @task.params = ArgumentDictionary.( test[1] ) 
          # Run the generated command line from cluster_commands
          exit_code = runTestScript( @task.cluster_commands[0].gsub('./'+TestScriptName,''), test[3] || [] )
          # Check that the exit code is appropriate
          expect( exit_code ).to eq( test[2] )
        end
      end

    end
  end

  # TODO test file overwrite + renaming, trailing spaces
  describe 'Cbrain Internal' do

    context 'Output File Handling' do
    
      # TODO FactoryGirl methods should be used, but only if they get rolled back in the before(:each)
      before(:each) do
#        puts FlatDirLocalDataProvider.all.inspect
#        FlatDirLocalDataProvider.all[0].remote_dir = '.'

        puts '\nBefore: '+Userfile.all.inspect
#        Userfile.all[0].remote_dir = '.'
        Userfile.all.each{ |uf| uf.destroy }
        puts '\nAfter: '+Userfile.all.inspect
      

        @fname = 'r.txt'
        FileUtils.touch(@fname)
        ftype = lambda { |fname| Userfile.suggested_file_type(fname) || SingleFile }
        @userfileClass = ftype.(@fname)

#        puts FlatDirLocalDataProvider.where(:id => 1).inspect
        # Get the schema and json descriptor
        descriptor     = File.join(__dir__, 'descriptor_test.json')
        # Generate a new task class via the Boutiques framework and integrate it into cbrain
        @boutiquesTask = SchemaTaskGenerator.generate(SchemaTaskGenerator.default_schema, descriptor)
        ClassName = 'CbrainTask::BoutiquesTest'
        raise "Class already defined!" if defined?(ClassName) == 'constant' && ClassName.class == Class
        @boutiquesTask.integrate
        @task          = CbrainTask::BoutiquesTest.new
#        @task_const = "CbrainTask::#{SchemaTaskGenerator.classify(@task.name)}".constantize
#        raise "Class not defined!" unless defined?(ClassName) == 'constant' && ClassName.class == Class
        # Look for a data provider
        puts "Pre deletion: "+FlatDirLocalDataProvider.all.inspect
        DataProvider.all.each { |dp| dp.destroy }
        puts "Post deletion: "+FlatDirLocalDataProvider.all.inspect

        @provider      = FlatDirLocalDataProvider.new({ :online => true, :read_only => false, :remote_dir => '.' })
        @provider.id   = 9
        @provider.name = 'test_provider'
        @provider.user_id  = User.admin.id
        @provider.group_id = Group.everyone.id
        @provider.save! 
        
        puts "Post-creation: "+FlatDirLocalDataProvider.all.inspect

        # Add a local input file to it (allows smarter lookup in userfile_exists)
        file_c, ft  = 'c', ftype.(file_c)
        
        puts "PRE File existence check " + @task.userfile_exists( ft ,{:name => file_c, :data_provider_id => @provider.id}).to_s

        puts "\n\nUF pre" + Userfile.all.inspect    
        newFile = @task.safe_userfile_find_or_new( ft  , :name => file_c, :data_provider_id => @provider.id, :user_id => User.admin.id, :group_id => Group.everyone.id)    
        newFile.save!
        puts "\nUF post" + Userfile.all.inspect
 #       puts "newFile name: "+newFile.name.to_s

        puts "\nID = " + Userfile.all.first.id.to_s

        @task.params   = {:ro => @fname, :interface_userfile_ids => [Userfile.all.first.id]}
        @task.user_id  = User.admin.id
        @task.group_id = Group.everyone.id
         
#       newFile.cache_copy_from_local_file( file_c )    
        # Generate a simulated exit file, as if the task had run
        @simExitFile = @task.exit_cluster_filename

        FileUtils.touch( @simExitFile )
        # Give access to the generated task class itself
#        @task_const = "CbrainTask::#{SchemaTaskGenerator.classify(@task.name)}".constantize

#        provider = FlatDirLocalDataProvider.where( :name => "dataprovider_1").first  
#        provider = FactoryGirl.create(:data_provider, :online => true, :read_only => false)

        puts "File existence check " + @task.userfile_exists( ft ,{:name => file_c, :data_provider_id => @provider.id}).to_s

#        puts @provider.inspect
#        dp = DataProvider.all
#        puts dp.inspect
      end

      after(:each) do
        # Delete any generated output files
        destroyOutputFiles
        # Also need to get rid of the exit file
        fname = '.qsub.exit.BoutiquesTest.-1'
        File.delete( fname ) if File.exists?( fname )
        # Destroy the registered userfiles and the data_provider, so as not to affect downstream tests
        # Necessary for tests that create and/or register userfiles in the it block
        Userfile.all.each{ |uf| uf.destroy }
        DataProvider.all.each { |dp| dp.destroy }
      end

      it "can save results files" do
        # 
        expect( File.exists? @fname ).to be true
        #
        expect( @task.userfile_exists(@userfileClass,{:name => @fname, :data_provider_id => @provider.id}) ).to be false        
        #
        puts "\nSave Results: " +  @task.save_results.to_s
        #
        expect( @task.userfile_exists(@userfileClass,{:name => @fname, :data_provider_id => @provider.id}) ).to be true
      end

      # Ensure the files do not survive between tests
      it 'should destroy results files between tests' do
        expect( @task.userfile_exists(@userfileClass,{:name => @fname, :data_provider_id => @provider.id}) ).to be false
      end

      it "renames results files" do
        puts "\n\nthird test\n"
        # 
        expect( File.exists? @fname ).to be true
        #
        expect( @task.userfile_exists(@userfileClass,{:name => @fname, :data_provider_id => @provider.id}) ).to be false
        #
        puts "\nSave Results: " +  @task.save_results.to_s
        #
        expect( @task.userfile_exists(@userfileClass,{:name => @fname, :data_provider_id => @provider.id}) ).to be true
        # Create a new task and have it save results as well
        task2 = CbrainTask::BoutiquesTest.new
        task2.params   = {:ro => @fname, :interface_userfile_ids => [Userfile.all.first.id]}
        task2.user_id  = User.admin.id
        task2.group_id = Group.everyone.id
        puts "\nSave Results: " +  task2.save_results.to_s
        puts "task2 post ufs : " + Userfile.all.inspect
        # Initial file should still be there with the correct name
        expect( @task.userfile_exists(@userfileClass,{:name => @fname, :data_provider_id => @provider.id}) ).to be true
        puts "orig entry: " + Userfile.where( :name => @fname ).first.inspect
        expect( Userfile.where( :name => @fname ).first.nil? ).not_to be true
        # New file should be renamed appropriately
        puts "second entry" + Userfile.all.last.inspect
        expect( Userfile.all.last.name =~ /^r-.*-\d{9}\.txt$/ ).to eq(0)
      end

    end

    # Test that a Tool Config is created iff both the bourreau and the descriptor specify docker
    context 'Default ToolConfig creation' do

      before(:each) do
        # Ensure the Bourreau does not have docker installed by default
        resource = RemoteResource.current_resource
        resource.docker_present = false
        resource.save!
        # Get the schema and json descriptor
        schema           = SchemaTaskGenerator.default_schema
        @descriptor      = File.join(__dir__, 'descriptor_test.json')
        # Generate a new task class via the Boutiques framework, without integrating it 
        @boutiquesTask   = SchemaTaskGenerator.generate(schema, @descriptor)
        @boutiquesTask.descriptor["docker-image"] = nil # tool does not use docker by default
        @task_const_name = "CbrainTask::#{SchemaTaskGenerator.classify(@boutiquesTask.name)}"
        # Destroy any tools/toolconfigs for the tool, if any exist
        ToolConfig.where(tool_id: CbrainTask::BoutiquesTest.tool.id).destroy_all rescue nil
        Tool.where(:cbrain_task_class => @task_const_name).destroy_all rescue nil
      end

      after(:each) do
        # Destroy any tools/toolconfigs for the tool, if any exist
        ToolConfig.where(tool_id: @task_const_name.constantize.tool.id).destroy_all
        Tool.where(:cbrain_task_class => @task_const_name).destroy_all 
        # Ensure the Bourreau does not have docker installed by default
        resource = RemoteResource.current_resource
        resource.docker_present = false
        resource.save!
      end
      
      it "is not done with only docker in task" do
        @boutiquesTask.descriptor['docker-image'] = 'placeholder_string'
        @boutiquesTask.integrate if File.exists?(@descriptor)
        expect( ToolConfig.exists?( :tool_id => @task_const_name.constantize.tool.id ) ).to be false
      end
      it "is not done with only docker in bourreau" do
        RemoteResource.current_resource.docker_present = true
        RemoteResource.current_resource.save!
        @boutiquesTask.integrate if File.exists?(@descriptor)
        expect( ToolConfig.exists?( :tool_id => @task_const_name.constantize.tool.id ) ).to be false
      end
      it "is done with docker in both task and bourreau" do
        @boutiquesTask.descriptor['docker-image'] = 'placeholder_string'
        resource       = RemoteResource.current_resource
        resource.docker_present = true
        resource.save!
        @boutiquesTask.integrate if File.exists?(@descriptor)
        expect( ToolConfig.exists?( :tool_id => @task_const_name.constantize.tool.id ) ).to be true
      end
      # Also checks that the integration changes were rolled back
      it "is not done without docker in task and bourreau" do 
        @boutiquesTask.integrate if File.exists?(@descriptor)
        expect( ToolConfig.exists?( :tool_id => @task_const_name.constantize.tool.id ) ).to be false
      end

    end     
  
  end

end

