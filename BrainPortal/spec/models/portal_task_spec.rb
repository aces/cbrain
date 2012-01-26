
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

describe PortalTask do
  
  let(:portal_task) { Factory.create(:portal_task) }
  
  describe "#add_new_params_defaults" do
    it "should add default params to the params hash" do
      default_args = {:default_key => :default_value}
      given_params = {:key => :value}
      PortalTask.stub!(:default_launch_args).and_return(default_args)
      portal_task.params = given_params
      portal_task.add_new_params_defaults
      portal_task.params.should == default_args.merge(given_params)
    end
    it "should not crush given param values" do
      default_args     = {:key => :default_value}
      collision_params = {:key => :given_value}
      PortalTask.stub!(:default_launch_args).and_return(default_args)
      portal_task.params = collision_params
      portal_task.add_new_params_defaults
      portal_task.params.should == collision_params
    end
  end
  describe "#properties" do
    it "should return the properties hash" do
      PortalTask.properties.should be_a Hash
    end
  end
  describe "#default_launch_args" do
    it "should return an empty hash" do
      PortalTask.default_launch_args.should == {}
    end
  end
  describe "#pretty_params_names" do
    it "should return an empty hash"do
      PortalTask.pretty_params_names.should == {}
    end
  end
  describe "#before_form" do
    it "should return an empty string" do
      portal_task.before_form.should == ""
    end
  end
  describe "#refresh_form" do
    it "should return an empty string" do
      portal_task.refresh_form.should == ""
    end
  end
  describe "#after_form" do
    it "should return an empty string" do
      portal_task.after_form.should == ""
    end
  end
  describe "#final_task_list" do
    it "should return an array with the task itself" do
      portal_task.final_task_list.should == [portal_task]
    end
  end
  describe "#after_final_task_list_saved" do
    it "should return an empty string" do
      portal_task.after_final_task_list_saved([portal_task]).should == ""
    end
  end
  describe "#untouchable_params_attributes" do
    it "should have interface_userfile_ids set" do
      portal_task.untouchable_params_attributes.should include(:interface_userfile_ids)
    end
  end
  describe "#unpresetable_params_attributes" do
    it "should return an empty hash" do
      portal_task.unpresetable_params_attributes.should == {}
    end
  end
  describe "#wrapper_default_launch_args" do
    it "should call default_launch_args" do
      PortalTask.should_receive(:default_launch_args).and_return({})
      PortalTask.wrapper_default_launch_args
    end
    it "should raise an error if default args is not a hash" do
      PortalTask.stub!(:default_launch_args).and_return(nil)
      lambda { PortalTask.wrapper_default_launch_args }.should raise_error(ScriptError)
    end
    it "should reraise CbrainErrors" do
      PortalTask.stub!(:default_launch_args).and_raise(CbrainError)
      lambda { PortalTask.wrapper_default_launch_args }.should raise_error(CbrainError)
    end
    it "should reraise CbrainNotices" do
      PortalTask.stub!(:default_launch_args).and_raise(CbrainNotice)
      lambda { PortalTask.wrapper_default_launch_args }.should raise_error(CbrainNotice)
    end
    it "should convert other errors to ScriptErrors" do
      PortalTask.stub!(:default_launch_args).and_raise(StandardError)
      lambda { PortalTask.wrapper_default_launch_args }.should raise_error(ScriptError)
    end
  end
  describe "#wrapper_before_form" do
    it "should call before_form" do
      portal_task.should_receive(:before_form).and_return("")
      portal_task.wrapper_before_form
    end
    it "should raise an error if default args is not a string" do
      portal_task.stub!(:before_form).and_return(nil)
      lambda { portal_task.wrapper_before_form }.should raise_error(ScriptError)
    end
    it "should raise an error if refresh_form saves the object" do
      portal_task.stub!(:new_record?).and_return(true, false)
      lambda { portal_task.wrapper_before_form }.should raise_error(ScriptError)
    end
    it "should reraise CbrainErrors" do
      portal_task.stub!(:before_form).and_raise(CbrainError)
      lambda { portal_task.wrapper_before_form }.should raise_error(CbrainError)
    end
    it "should reraise CbrainNotices" do
      portal_task.stub!(:before_form).and_raise(CbrainNotice)
      lambda { portal_task.wrapper_before_form }.should raise_error(CbrainNotice)
    end
    it "should convert other errors to ScriptErrors" do
      portal_task.stub!(:before_form).and_raise(StandardError)
      lambda { portal_task.wrapper_before_form }.should raise_error(ScriptError)
    end
  end
  describe "#wrapper_refresh_form" do
    it "should call refresh_form" do
      portal_task.should_receive(:refresh_form).and_return("")
      portal_task.wrapper_refresh_form
    end
    it "should raise an error if refresh_form return value is not a string" do
      portal_task.should_receive(:refresh_form).and_return(nil)
      lambda { portal_task.wrapper_refresh_form }.should raise_error(ScriptError)
    end
    it "should raise an error if refresh_form saves the object" do
      portal_task.stub!(:new_record?).and_return(true, false)
      lambda { portal_task.wrapper_refresh_form }.should raise_error(ScriptError)
    end
    it "should register CbrainErrors as errors on the object" do
      portal_task.stub!(:refresh_form).and_raise(CbrainError)
      portal_task.wrapper_refresh_form
      portal_task.errors.should include(:base)
    end
    it "should register CbrainNotices as errors on the object" do
      portal_task.stub!(:refresh_form).and_raise(CbrainNotice)
      portal_task.wrapper_refresh_form
      portal_task.errors.should include(:base)
    end
    it "should convert other errors to ScriptErrors" do
      portal_task.should_receive(:refresh_form).and_raise(StandardError)
      lambda { portal_task.wrapper_refresh_form }.should raise_error(ScriptError)
    end
  end
  describe "#wrapper_after_form" do
    it "should call after_form" do
      portal_task.should_receive(:after_form).and_return("")
      portal_task.wrapper_after_form
    end
    it "should raise an error if default args is not a string" do
      portal_task.stub!(:after_form).and_return(nil)
      lambda { portal_task.wrapper_after_form }.should raise_error(ScriptError)
    end
    it "should raise an error if after_form saves the object and property not set to allow saving" do
      PortalTask.stub!(:properties).and_return(:i_save_my_task_in_after_form => false)
      portal_task.stub!(:new_record?).and_return(true, false)
      lambda { portal_task.wrapper_after_form }.should raise_error(ScriptError)
    end
    it "should not raise an error if after_form saves the object and property set to allow saving" do
      PortalTask.stub!(:properties).and_return(:i_save_my_task_in_after_form => true)
      portal_task.stub!(:new_record?).and_return(true, false)
      lambda { portal_task.wrapper_after_form }.should_not raise_error(ScriptError)
    end
    it "should reraise CbrainErrors" do
      portal_task.stub!(:after_form).and_raise(CbrainError)
      lambda { portal_task.wrapper_after_form }.should raise_error(CbrainError)
    end
    it "should reraise CbrainNotices" do
      portal_task.stub!(:after_form).and_raise(CbrainNotice)
      lambda { portal_task.wrapper_after_form }.should raise_error(CbrainNotice)
    end
    it "should convert other errors to ScriptErrors" do
      portal_task.stub!(:after_form).and_raise(StandardError)
      lambda { portal_task.wrapper_after_form }.should raise_error(ScriptError)
    end
  end
  describe "#wrapper_final_task_list" do
    before(:each) do
      portal_task.stub!(:new_record?).and_return(true)
    end
    
    it "should call final_task_list" do
      portal_task.should_receive(:final_task_list).and_return([portal_task])
      portal_task.wrapper_final_task_list
    end
    it "should raise an error if final_task_list does not return an array" do
      portal_task.stub!(:final_task_list).and_return(nil)
      lambda { portal_task.wrapper_final_task_list }.should raise_error(ScriptError)
    end
    it "should raise an error if final_task_list returns an array that doesn't contain CbrainTasks" do
      portal_task.stub!(:final_task_list).and_return([nil])
      lambda { portal_task.wrapper_final_task_list }.should raise_error(ScriptError)
    end
    it "should raise an error if final_task_list saves objects and property not set to allow saving" do
      PortalTask.stub!(:properties).and_return(:i_save_my_tasks_in_final_task_list => false)
      portal_task.stub!(:new_record?).and_return(false)
      lambda { portal_task.wrapper_final_task_list }.should raise_error(ScriptError)
    end
    it "should not raise an error if final_task_list saves objects and property set to allow saving" do
      PortalTask.stub!(:properties).and_return(:i_save_my_tasks_in_final_task_list => true)
      portal_task.stub!(:new_record?).and_return(false)
      lambda { portal_task.wrapper_final_task_list }.should_not raise_error(ScriptError)
    end
    it "should reraise CbrainErrors" do
      portal_task.stub!(:final_task_list).and_raise(CbrainError)
      lambda { portal_task.wrapper_final_task_list }.should raise_error(CbrainError)
    end
    it "should reraise CbrainNotices" do
      portal_task.stub!(:final_task_list).and_raise(CbrainNotice)
      lambda { portal_task.wrapper_final_task_list }.should raise_error(CbrainNotice)
    end
    it "should convert other errors to ScriptErrors" do
      portal_task.stub!(:final_task_list).and_raise(StandardError)
      lambda { portal_task.wrapper_final_task_list }.should raise_error(ScriptError)
    end
  end
  describe "#wrapper_after_final_task_list_saved" do
    it "should call after_final_task_list_saved" do
      portal_task.should_receive(:after_final_task_list_saved).and_return("")
      portal_task.wrapper_after_final_task_list_saved([portal_task])
    end
    it "should raise an error if after_final_task_list_saved does not return a string" do
      portal_task.should_receive(:after_final_task_list_saved).and_return(nil)
      lambda { portal_task.wrapper_after_final_task_list_saved([portal_task]) }.should raise_error(ScriptError)
    end
    it "should reraise CbrainErrors" do
      portal_task.stub!(:after_final_task_list_saved).and_raise(CbrainError)
      lambda { portal_task.wrapper_after_final_task_list_saved([portal_task]) }.should raise_error(CbrainError)
    end
    it "should reraise CbrainNotices" do
      portal_task.stub!(:after_final_task_list_saved).and_raise(CbrainNotice)
      lambda { portal_task.wrapper_after_final_task_list_saved([portal_task]) }.should raise_error(CbrainNotice)
    end
    it "should convert other errors to ScriptErrors" do
      portal_task.stub!(:after_final_task_list_saved).and_raise(StandardError)
      lambda { portal_task.wrapper_after_final_task_list_saved([portal_task]) }.should raise_error(ScriptError)
    end
  end
  describe "#wrapper_untouchable_params_attributes" do
    it "should call untouchable_params_attributes" do
      portal_task.should_receive(:untouchable_params_attributes).and_return(nil)
      portal_task.wrapper_untouchable_params_attributes
    end
    it "should add :interface_userfile_ids to the untouchable params hash" do
      portal_task.stub!(:untouchable_params_attributes).and_return({})
      portal_task.wrapper_untouchable_params_attributes.should include(:interface_userfile_ids)
    end
  end
  describe "#wrapper_unpresetable_params_attributes" do
    it "should call unpresetable_params_attributes" do
      portal_task.should_receive(:unpresetable_params_attributes).and_return(nil)
      portal_task.wrapper_unpresetable_params_attributes
    end
    it "should default to an empty hash" do
      portal_task.stub!(:unpresetable_params_attributes).and_return(nil)
      portal_task.wrapper_unpresetable_params_attributes.should == {}
    end
    it "should return the value returned by unpresetable_params_attributes" do
      return_value = {:key => :value}
      portal_task.stub!(:unpresetable_params_attributes).and_return(return_value)
      portal_task.wrapper_unpresetable_params_attributes.should == return_value
    end
  end
  describe "#params_errors" do
    let(:param_errors) { double("param_errors").as_null_object }
    
    it "should create a new ParamsErrors object" do
      PortalTask::ParamsErrors.should_receive(:new).and_return(param_errors)
      portal_task.params_errors
    end
    it "should set the real_errors attribute on the params_errors" do
      PortalTask::ParamsErrors.stub!(:new).and_return(param_errors)
      param_errors.should_receive(:real_errors=)
      portal_task.params_errors
    end
  end
  describe "#human_attribute_name" do
    it "should remove the cbrain_tasks_param part from the string if it's there'" do
      PortalTask.human_attribute_name("cbrain_task_params_xyz").should == "xyz"
    end
    it "should use the pretty names hash if it applies" do
      PortalTask.stub!(:pretty_params_names).and_return("cbrain_task_params_xyz" => "pretty")
      PortalTask.human_attribute_name("cbrain_task_params_xyz").should == "pretty"
    end
    it "should convert the pretty names sub hash keys if they haven't already beed" do
      PortalTask.stub!(:pretty_params_names).and_return("xyz[abc]" => "pretty")
      PortalTask.human_attribute_name("cbrain_task_params_xyz_abc").should == "pretty"
    end
    it "should return the humanized version of the string if cbrain_tasks part isn't there" do
      PortalTask.human_attribute_name("my_xyz").should == "my_xyz".humanize
    end
  end
  describe "#restore_untouchable_attributes" do
    let(:old_values) { {untouchable_param:1, unpresetable_param:2, touchable_param:3, presetable_param:4} }
    let(:new_values) { {untouchable_param:5, unpresetable_param:6, touchable_param:7, presetable_param:8} }
    
    before(:each) do
      portal_task.stub!(:wrapper_untouchable_params_attributes).and_return(:untouchable_param => true)
      portal_task.stub!(:wrapper_unpresetable_params_attributes).and_return(:unpresetable_param => true)
      portal_task.params = new_values
    end
    it "should set any params to old values if they are in the untouchable hash" do
      portal_task.restore_untouchable_attributes(old_values)
      portal_task.params[:untouchable_param].should == old_values[:untouchable_param]
    end
    it "should not set any params to old values if they are not in the untouchable hash" do
      portal_task.restore_untouchable_attributes(old_values)
      portal_task.params[:touchable_param].should == new_values[:touchable_param]
    end
    it "should set any params to old values if they are in the unpresetable hash and the option is set" do
      portal_task.restore_untouchable_attributes(old_values, :include_unpresetable => true)
      portal_task.params[:unpresetable_param].should == old_values[:unpresetable_param]
    end
    it "should not set any params to old values if they are not in the unpresetable hash" do
      portal_task.restore_untouchable_attributes(old_values, :include_unpresetable => true)
      portal_task.params[:presetable_param].should == new_values[:presetable_param]
    end
    it "should not set any params to old values if they are in the unpresetable hash but the option is not set" do
      portal_task.restore_untouchable_attributes(old_values)
      portal_task.params[:unpresetable_param].should == new_values[:unpresetable_param]
    end
    
  end
  describe "::ParamsErrors" do
    let(:params_errors) { PortalTask::ParamsErrors.new }
    let(:real_errors)   { double("real_errors").as_null_object }
    let(:param_path)    { "param_path" }
    
    before(:each) do
      params_errors.real_errors = real_errors
    end
    
    describe "#on" do
      it "should convert the path argument to la and forward it" do
        real_errors.should_receive(:on).with(param_path.to_la_id)
        params_errors.on(param_path)
      end
    end
    describe "#[]" do
      it "should convert the path argument to la and forward an #on call" do
        real_errors.should_receive(:on).with(param_path.to_la_id)
        params_errors[param_path]
      end
    end
    describe "#add" do
      it "should convert the path argument to la and forward it" do
        real_errors.should_receive(:add).with(param_path.to_la_id)
        params_errors.add(param_path)
      end
    end
    describe "#add_on_blank" do
      it "should convert the path arguments to la and forward it" do
        real_errors.should_receive(:add_on_blank).with([param_path.to_la_id])
        params_errors.add_on_blank([param_path])
      end
    end
    describe "#add_on_empty" do
      it "should convert the path argument to la and forward it" do
        real_errors.should_receive(:add_on_empty).with([param_path.to_la_id])
        params_errors.add_on_empty([param_path])
      end
    end
    describe "#add_to_base" do
      it "should convert the path argument to la and forward it" do
        real_errors.should_receive(:add_to_base)
        params_errors.add_to_base
      end
    end
    describe "#size" do
      it "should forward the call" do
        real_errors.should_receive(:size)
        params_errors.size
      end
    end
    describe "#count" do
      it "should forward a #size call" do
        real_errors.should_receive(:size)
        params_errors.count
      end
    end
    describe "#length" do
      it "should forward a #size call" do
        real_errors.should_receive(:size)
        params_errors.length
      end
    end
    describe "#clear" do
      it "should forward the call" do
        real_errors.should_receive(:clear)
        params_errors.clear
      end
    end
    describe "#each" do
      it "should forward the call" do
        real_errors.should_receive(:each)
        params_errors.each
      end
    end
    describe "#each_full" do
      it "should forward the call" do
        real_errors.should_receive(:each_full)
        params_errors.each_full
      end
    end
    describe "#empty?" do
      it "should forward the call" do
        real_errors.should_receive(:empty?)
        params_errors.empty?
      end
    end
    describe "#full_messages" do
      it "should forward the call" do
        real_errors.should_receive(:full_messages)
        params_errors.full_messages
      end
    end
    describe "#generate_message" do
      it "should convert the path argument to la and forward it" do
        real_errors.should_receive(:generate_message).with(param_path.to_la_id)
        params_errors.generate_message(param_path)
      end
    end
    describe "#invalid?" do
      it "should convert the path argument to la and forward it" do
        real_errors.should_receive(:invalid?).with(param_path.to_la_id)
        params_errors.invalid?(param_path)
      end
    end
    describe "#on_base" do
      it "should forward the call" do
        real_errors.should_receive(:on_base)
        params_errors.on_base
      end
    end
    describe "#to_xml" do
      it "should forward the call" do
        real_errors.should_receive(:on_base)
        params_errors.on_base
      end
    end
  end
end

