
# Required files for inclusion
require 'spec_helper'
require_relative 'portal_boutiques_test/test_helpers'

# Add helper methods for performing tests
include TestHelpers

# Testing the Boutiques framework on the Bourreau side
describe "Bourreau Boutiques Tests" do

  # Testing Boutiques via the submission of a local script
  describe 'Local Script Writing' do

    # Run before block to create required input files
    before(:each) do
      schema = SchemaTaskGenerator.default_schema
      descriptor = File.join(__dir__, 'descriptor_test.json')
      @boutiquesTask = SchemaTaskGenerator.generate(schema, descriptor)
      @boutiquesTask.integrate if File.exists?(descriptor)
      @task = CbrainTask::BoutiquesTest.new
      @task_const = "CbrainTask::#{SchemaTaskGenerator.classify(@task.name)}".constantize
    end

    context "generated task submission" do
      it "check cluster commands" do        
        @task.params = {}
        @task = CbrainTask::BoutiquesTest.new
        @task.params[:A] = "A"
        puts @task.cluster_commands
      end
    end

  end

end

