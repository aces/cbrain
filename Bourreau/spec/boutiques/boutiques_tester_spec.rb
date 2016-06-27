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
    File.delete('c','f','jf','f1','f2')
    PotenOutFiles.each { |f| File.delete(f) if File.exist?(f) }
  end

  # Run before block to create ClusterTask object
  before(:each) do
    schema = SchemaTaskGenerator.default_schema
    descriptor = File.join(__dir__, 'descriptor_test.json')
    @boutiquesTask = SchemaTaskGenerator.generate(schema, descriptor)
    @boutiquesTask.integrate if File.exists?(descriptor)
    @task = CbrainTask::BoutiquesTest.new
    @task.params = {}
    @task_const = "CbrainTask::#{SchemaTaskGenerator.classify(@task.name)}".constantize
  end

  # Tests expected behaviour of the auto-generated cluster task for the  
  describe "Generated ClusterTask Object" do
   
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
      it "handles special meaning characters" do
        s = @task.apply_template(@template, @def_keys.merge({'[4]' => " '; arg"}))
        expect( s.strip ).to eq( "cmd one.txt 2 t.csv ' '\\''; arg'" )
      end

      it "handles substitutions with flags" do
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
              flags: @flags.merge({'[4]' => '-f'}),
              separators: @seps)
        expect( s.strip ).to eq( "cmd -1=one.txt --long-flag~2 -t t.csv -f" )
      end

      it "properly strips endings" do
        s = @task.apply_template(@template,  
              @def_keys.merge({'[4]' => true, '[5]' => '9.tex'}),
              flags: @flags.merge({'[4]' => '-f', '[5]' => '-tex'}),
              separators: @seps, 
              strip: [ '.txt', '.tex' ])
        expect( s.strip ).to eq( "cmd -1=one --long-flag~2 -t t.csv -f -tex 9" )
      end

    end
    
    # Test that creating a basic cluster command in isolation works
    it "can create cluster commands" do        
      @task.params[:A] = "A_VAL"
      expect( @task.cluster_commands[0].strip ).to eq( './' + TestScriptName + ' -A A_VAL' )
    end
    
  end

  # Testing Boutiques via the mock 'submission' of a local script
  context 'Cluster Command Generation with Mock Program' do
    
    # After each local test, destroy the output files, so they don't interfere with downstream tests
    after(:each) do
      destroyOutputFiles
    end

    # Perform tests by running the cmd line given by cluster commands and checking the exit code
    BasicTests.each do |test|
      # Testing for unrecognized inputs will not work here, since apply_template will ignore them
      next if test[0].include?( "unrecognized" )
      # The apply_template method adds the separator on its own, so we need only check that works
      next if test[0].include?( "fails when special separator" )
      # Run the test
      it "#{test[0]}" do
        # Convert string argument to params dict
#        puts "\n\nORIG: " + test[1]
        @task.params = ArgumentDictionary.( test[1] ) 
#        puts "DICT: " + @task.params.to_s
#        puts "CC: " + @task.cluster_commands[0].to_s
        # Run the generated command line from cluster_commands
        exit_code = runTestScript( @task.cluster_commands[0].gsub('./'+TestScriptName,''), test[3] || [] )
        # Check that the exit code is appropriate
        expect( exit_code ).to eq( test[2] )
      end
    end

  end

  # TODO check for API existence
  # TODO run tests via cbrain api
  # TODO test file overwrite, renaming, trailing spaces, tool config presence only with docker
  describe 'Cbrain API Boutiques Tests' do
        
  end

end

