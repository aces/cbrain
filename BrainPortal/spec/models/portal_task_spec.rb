
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

describe PortalTask do

  let(:portal_task) { create("cbrain_task/diagnostics") }

  describe "#add_new_params_defaults" do

    it "should add default params to the params hash" do
      default_args = {:default_key => :default_value}
      given_params = {:key => :value}
      allow(portal_task.class).to receive(:default_launch_args).and_return(default_args)
      portal_task.params = given_params
      portal_task.add_new_params_defaults
      expect(portal_task.params).to eq(default_args.merge(given_params))
    end

    it "should not crush given param values" do
      default_args     = {:key => :default_value}
      collision_params = {:key => :given_value}
      allow(portal_task.class).to receive(:default_launch_args).and_return(default_args)
      portal_task.params = collision_params
      portal_task.add_new_params_defaults
      expect(portal_task.params).to eq(collision_params)
    end
  end

  describe "#properties" do

    it "should return the properties hash" do
      expect(PortalTask.properties).to be_a Hash
    end

  end

  describe "#default_launch_args" do

    it "should return an empty hash" do
      expect(PortalTask.default_launch_args).to eq({})
    end

  end

  describe "#pretty_params_names" do

    it "should return an empty hash"do
      expect(PortalTask.pretty_params_names).to eq({})
    end

  end

  describe "#before_form" do

    it "should return an empty string" do
      expect(portal_task.before_form).to eq("")
    end

  end

  describe "#after_form" do
    it "should return an empty string" do
      expect(portal_task.after_form).to eq("")
    end

  end

  describe "#after_final_task_list_saved" do

    it "should return an empty string" do
      expect(portal_task.after_final_task_list_saved([portal_task])).to eq("")
    end

  end

  describe "#unpresetable_params_attributes" do

    it "should return an empty hash" do
      expect(portal_task.unpresetable_params_attributes).to eq({})
    end

  end

  describe "#wrapper_default_launch_args" do

    it "should call default_launch_args" do
      expect(PortalTask).to receive(:default_launch_args).and_return({})
      PortalTask.wrapper_default_launch_args
    end

    it "should raise an error if default args is not a hash" do
      allow(PortalTask).to receive(:default_launch_args).and_return(nil)
      expect { PortalTask.wrapper_default_launch_args }.to raise_error(ScriptError)
    end

    it "should reraise CbrainErrors" do
      allow(PortalTask).to receive(:default_launch_args).and_raise(CbrainError)
      expect { PortalTask.wrapper_default_launch_args }.to raise_error(CbrainError)
    end

    it "should reraise CbrainNotices" do
      allow(PortalTask).to receive(:default_launch_args).and_raise(CbrainNotice)
      expect { PortalTask.wrapper_default_launch_args }.to raise_error(CbrainNotice)
    end

    it "should convert other errors to ScriptErrors" do
      allow(PortalTask).to receive(:default_launch_args).and_raise(StandardError)
      expect { PortalTask.wrapper_default_launch_args }.to raise_error(ScriptError)
    end

  end

  describe "#wrapper_before_form" do

    it "should call before_form" do
      expect(portal_task).to receive(:before_form).and_return("")
      portal_task.wrapper_before_form
    end

    it "should raise an error if default args is not a string" do
      allow(portal_task).to receive(:before_form).and_return(nil)
      expect { portal_task.wrapper_before_form }.to raise_error(ScriptError)
    end

    it "should raise an error if refresh_form saves the object" do
      allow(portal_task).to receive(:new_record?).and_return(true, false)
      expect { portal_task.wrapper_before_form }.to raise_error(ScriptError)
    end

    it "should reraise CbrainErrors" do
      allow(portal_task).to receive(:before_form).and_raise(CbrainError)
      expect { portal_task.wrapper_before_form }.to raise_error(CbrainError)
    end

    it "should reraise CbrainNotices" do
      allow(portal_task).to receive(:before_form).and_raise(CbrainNotice)
      expect { portal_task.wrapper_before_form }.to raise_error(CbrainNotice)
    end

    it "should convert other errors to ScriptErrors" do
      allow(portal_task).to receive(:before_form).and_raise(StandardError)
      expect { portal_task.wrapper_before_form }.to raise_error(ScriptError)
    end

  end

  describe "#wrapper_refresh_form" do

    it "should call refresh_form" do
      expect(portal_task).to receive(:refresh_form).and_return("")
      portal_task.wrapper_refresh_form
    end

    it "should raise an error if refresh_form return value is not a string" do
      expect(portal_task).to receive(:refresh_form).and_return(nil)
      expect { portal_task.wrapper_refresh_form }.to raise_error(ScriptError)
    end

    it "should raise an error if refresh_form saves the object" do
      allow(portal_task).to receive(:new_record?).and_return(true, false)
      expect { portal_task.wrapper_refresh_form }.to raise_error(ScriptError)
    end

    it "should register CbrainErrors as errors on the object" do
      allow(portal_task).to receive(:refresh_form).and_raise(CbrainError)
      portal_task.wrapper_refresh_form
      expect(portal_task.errors).to include(:base)
    end

    it "should register CbrainNotices as errors on the object" do
      allow(portal_task).to receive(:refresh_form).and_raise(CbrainNotice)
      portal_task.wrapper_refresh_form
      expect(portal_task.errors).to include(:base)
    end

    it "should convert other errors to ScriptErrors" do
      expect(portal_task).to receive(:refresh_form).and_raise(StandardError)
      expect { portal_task.wrapper_refresh_form }.to raise_error(ScriptError)
    end

  end

  describe "#wrapper_after_form" do

    it "should call after_form" do
      expect(portal_task).to receive(:after_form).and_return("")
      portal_task.wrapper_after_form
    end

    it "should raise an error if default args is not a string" do
      allow(portal_task).to receive(:after_form).and_return(nil)
      expect { portal_task.wrapper_after_form }.to raise_error(ScriptError)
    end

    it "should raise an error if after_form saves the object and property not set to allow saving" do
      allow(portal_task.class).to receive(:properties).and_return(:i_save_my_task_in_after_form => false)
      allow(portal_task).to receive(:new_record?).and_return(true, false)
      expect { portal_task.wrapper_after_form }.to raise_error(ScriptError)
    end

    it "should not raise an error if after_form saves the object and property set to allow saving" do
      allow(portal_task.class).to receive(:properties).and_return(:i_save_my_task_in_after_form => true)
      allow(portal_task).to receive(:new_record?).and_return(true, false)
      expect { portal_task.wrapper_after_form }.not_to raise_error
    end

    it "should reraise CbrainErrors" do
      allow(portal_task).to receive(:after_form).and_raise(CbrainError)
      expect { portal_task.wrapper_after_form }.to raise_error(CbrainError)
    end

    it "should reraise CbrainNotices" do
      allow(portal_task).to receive(:after_form).and_raise(CbrainNotice)
      expect { portal_task.wrapper_after_form }.to raise_error(CbrainNotice)
    end

    it "should convert other errors to ScriptErrors" do
      allow(portal_task).to receive(:after_form).and_raise(StandardError)
      expect { portal_task.wrapper_after_form }.to raise_error(ScriptError)
    end

  end

  describe "#wrapper_final_task_list" do
    before(:each) do
      allow(portal_task).to receive(:new_record?).and_return(true)
    end

    it "should call final_task_list" do
      expect(portal_task).to receive(:final_task_list).and_return([portal_task])
      portal_task.wrapper_final_task_list
    end

    it "should raise an error if final_task_list does not return an array" do
      allow(portal_task).to receive(:final_task_list).and_return(nil)
      expect { portal_task.wrapper_final_task_list }.to raise_error(ScriptError)
    end

    it "should raise an error if final_task_list returns an array that doesn't contain CbrainTasks" do
      allow(portal_task).to receive(:final_task_list).and_return([nil])
      expect { portal_task.wrapper_final_task_list }.to raise_error(ScriptError)
    end

    it "should raise an error if final_task_list saves objects and property not set to allow saving" do
      allow(portal_task.class).to receive(:properties).and_return(:i_save_my_tasks_in_final_task_list => false)
      allow(portal_task).to receive(:new_record?).and_return(false)
      expect { portal_task.wrapper_final_task_list }.to raise_error(ScriptError)
    end

    it "should reraise CbrainErrors" do
      allow(portal_task).to receive(:final_task_list).and_raise(CbrainError)
      expect { portal_task.wrapper_final_task_list }.to raise_error(CbrainError)
    end

    it "should reraise CbrainNotices" do
      allow(portal_task).to receive(:final_task_list).and_raise(CbrainNotice)
      expect { portal_task.wrapper_final_task_list }.to raise_error(CbrainNotice)
    end

    it "should convert other errors to ScriptErrors" do
      allow(portal_task).to receive(:final_task_list).and_raise(StandardError)
      expect { portal_task.wrapper_final_task_list }.to raise_error(ScriptError)
    end

  end

  describe "#wrapper_after_final_task_list_saved" do

    it "should call after_final_task_list_saved" do
      expect(portal_task).to receive(:after_final_task_list_saved).and_return("")
      portal_task.wrapper_after_final_task_list_saved([portal_task])
    end

    it "should raise an error if after_final_task_list_saved does not return a string" do
      expect(portal_task).to receive(:after_final_task_list_saved).and_return(nil)
      expect { portal_task.wrapper_after_final_task_list_saved([portal_task]) }.to raise_error(ScriptError)
    end

    it "should reraise CbrainErrors" do
      allow(portal_task).to receive(:after_final_task_list_saved).and_raise(CbrainError)
      expect { portal_task.wrapper_after_final_task_list_saved([portal_task]) }.to raise_error(CbrainError)
    end

    it "should reraise CbrainNotices" do
      allow(portal_task).to receive(:after_final_task_list_saved).and_raise(CbrainNotice)
      expect { portal_task.wrapper_after_final_task_list_saved([portal_task]) }.to raise_error(CbrainNotice)
    end

    it "should convert other errors to ScriptErrors" do
      allow(portal_task).to receive(:after_final_task_list_saved).and_raise(StandardError)
      expect { portal_task.wrapper_after_final_task_list_saved([portal_task]) }.to raise_error(ScriptError)
    end

  end

  describe "#wrapper_untouchable_params_attributes" do

    it "should call untouchable_params_attributes" do
      expect(portal_task).to receive(:untouchable_params_attributes).and_return(nil)
      portal_task.wrapper_untouchable_params_attributes
    end

    it "should add :interface_userfile_ids to the untouchable params hash" do
      allow(portal_task).to receive(:untouchable_params_attributes).and_return({})
      expect(portal_task.wrapper_untouchable_params_attributes).to include(:interface_userfile_ids)
    end

  end

  describe "#wrapper_unpresetable_params_attributes" do

    it "should call unpresetable_params_attributes" do
      expect(portal_task).to receive(:unpresetable_params_attributes).and_return(nil)
      portal_task.wrapper_unpresetable_params_attributes
    end

    it "should default to an empty hash" do
      allow(portal_task).to receive(:unpresetable_params_attributes).and_return(nil)
      expect(portal_task.wrapper_unpresetable_params_attributes).to eq({})
    end

    it "should return the value returned by unpresetable_params_attributes" do
      return_value = {:key => :value}
      allow(portal_task).to receive(:unpresetable_params_attributes).and_return(return_value)
      expect(portal_task.wrapper_unpresetable_params_attributes).to eq(return_value)
    end

  end

  describe "#params_errors" do
    let(:param_errors) { double("param_errors").as_null_object }

    it "should create a new ParamsErrors object" do
      expect(PortalTask::ParamsErrors).to receive(:new).and_return(param_errors)
      portal_task.params_errors
    end

    it "should set the real_errors attribute on the params_errors" do
      allow(PortalTask::ParamsErrors).to receive(:new).and_return(param_errors)
      expect(param_errors).to receive(:real_errors=)
      portal_task.params_errors
    end

  end

  describe "#human_attribute_name" do

    it "should remove the cbrain_tasks_param part from the string if it's there'" do
      expect(PortalTask.human_attribute_name("cbrain_task_BRA_params_KET__BRA_xyz_KET_")).to eq("Xyz")
    end

    it "should use the pretty names hash if it applies" do
      allow(PortalTask).to receive(:pretty_params_names).and_return("cbrain_task_params_xyz" => "pretty")
      expect(PortalTask.human_attribute_name("cbrain_task_params_xyz")).to eq("pretty")
    end

    it "should convert the pretty names sub hash keys if they haven't already been" do
      allow(PortalTask).to receive(:pretty_params_names).and_return("xyz[abc]" => "pretty")
      expect(PortalTask.human_attribute_name("cbrain_task_BRA_params_KET__BRA_xyz_KET__BRA_abc_KET_")).to eq("pretty")
    end

    it "should return the humanized version of the string if cbrain_tasks part isn't there" do
      expect(PortalTask.human_attribute_name("my_xyz")).to eq("my_xyz".humanize)
    end

  end

  describe "#restore_untouchable_attributes" do
    let(:old_values) { {untouchable_param:1, unpresetable_param:2, touchable_param:3, presetable_param:4} }
    let(:new_values) { {untouchable_param:5, unpresetable_param:6, touchable_param:7, presetable_param:8} }

    before(:each) do
      allow(portal_task).to receive(:wrapper_untouchable_params_attributes).and_return(:untouchable_param => true)
      allow(portal_task).to receive(:wrapper_unpresetable_params_attributes).and_return(:unpresetable_param => true)
      portal_task.params = new_values
    end

    it "should set any params to old values if they are in the untouchable hash" do
      portal_task.restore_untouchable_attributes(old_values)
      expect(portal_task.params[:untouchable_param]).to eq(old_values[:untouchable_param])
    end

    it "should not set any params to old values if they are not in the untouchable hash" do
      portal_task.restore_untouchable_attributes(old_values)
      expect(portal_task.params[:touchable_param]).to eq(new_values[:touchable_param])
    end

    it "should set any params to old values if they are in the unpresetable hash and the option is set" do
      portal_task.restore_untouchable_attributes(old_values, :include_unpresetable => true)
      expect(portal_task.params[:unpresetable_param]).to eq(old_values[:unpresetable_param])
    end

    it "should not set any params to old values if they are not in the unpresetable hash" do
      portal_task.restore_untouchable_attributes(old_values, :include_unpresetable => true)
      expect(portal_task.params[:presetable_param]).to eq(new_values[:presetable_param])
    end

    it "should not set any params to old values if they are in the unpresetable hash but the option is not set" do
      portal_task.restore_untouchable_attributes(old_values)
      expect(portal_task.params[:unpresetable_param]).to eq(new_values[:unpresetable_param])
    end

  end

  describe "::ParamsErrors" do
    let(:task)          { CbrainTask::Diagnostics.new }
    let(:params_errors) { task.params_errors }
    let(:real_errors)   { task.errors }
    let(:param_path)    { "test" }
    let(:msg)           { "is invalid" }

    before(:each) do
      real_errors.clear
      params_errors.add(param_path, "is bad")
      params_errors.add(param_path, msg)

      real_errors.add("user_id", "is bad")
    end

    describe "#[]" do

      it "should get the error from the real error object" do
        expect(real_errors).to receive(:"[]")
        params_errors[param_path]
      end

    end

    describe "#[]=" do

      it "should add the error in the real error object" do
        expect(real_errors).to receive(:add)
        params_errors[param_path] = msg
      end

    end

    describe "#add" do

      it "should add the error in the real error object" do
        expect(real_errors).to receive(:add)
        params_errors.add(param_path, msg)
      end

    end

    describe "#add_on_blank" do

      it "should add one error if only one param is blank" do
        params_errors.clear

        task.params = {
          :test => "",
          :test2 => "NOT BLANK"
        }

        params_errors.add_on_blank([:test, :test2])

        expect(params_errors.count).to eq(1)
      end

    end

    describe "#add_on_empty" do

      it "should add one error if only one param is empty" do
        params_errors.clear

        task.params = {
          :test => "",
          :test2 => "NOT EMPTY"
        }
        params_errors.add_on_empty([:test, :test2])

        expect(params_errors.count).to eq(1)
      end

    end

    describe "#as_json" do
      it "should return a valid json" do
        expect(params_errors.as_json.to_s).to eq("{\"test\"=>[\"is bad\", \"is invalid\"]}")
      end
    end

    describe "#blank?" do
      it "should return false when there are errors" do
        expect(params_errors.blank?).to eq(false)
      end

      it "should return true when there are no errors" do
        params_errors.clear
        expect(params_errors.blank?).to eq(true)
      end
    end

    describe "#count" do

      it "should return the number of params errors and exclude real errors" do
        expect(params_errors.count).to eq(2)
      end

    end

    describe "#clear" do

      it "should delete all the params errors" do
        params_errors.clear
        expect(params_errors.count).to eq(0)
      end

      it "should not delete the other errors" do
        params_errors.clear
        expect(real_errors.count).to eq(1)
      end

    end

    describe "#each" do

      it "should forward the call" do
        expect(real_errors).to receive(:each)
        params_errors.each
      end

    end

    describe "#empty?" do

      it "return false when there are params errors" do
        expect(params_errors.empty?).to eq(false)
      end

      it "return true when there aren't" do
        params_errors.clear
        expect(params_errors.empty?).to eq(true)
      end

    end

    describe "#full_messages" do

      it "should build strings that represent the full params errors messages" do
        expect(real_errors.full_messages).to be_kind_of(Array)
        real_errors.full_messages.each { |msg|
          expect(msg).to be_kind_of(String)
        }
      end

    end

    # describe "#full_messages_for" do

    #   it "should return messages for only params errors requested" do
    #     expect(params_errors.full_messages_for(param_path)).to be_kind_of(Array)
    #     expect(params_errors.full_messages_for(param_path).count).to eq(2)
    #   end

    # end

    describe "#get" do
      it "should return an array with the error messages for a parampath" do
        expect(params_errors.get(param_path)).to be_kind_of(Array)
        expect(params_errors.get(param_path).count).to eq(2)
      end
    end

    describe "#keys?" do
      it "should return an array of all the params that have errors" do
        expect(params_errors.keys[0]).to eq(param_path.to_s)
      end
    end

    describe "#set" do
      it "should forward the call to set to the real error object with the la parameter name" do
        expect(real_errors).to receive(:set).with(param_path.to_la_id.to_sym, Array(msg))
        params_errors.set(param_path.to_s, [msg])
      end
    end

    describe "#size" do

      it "should return the number of params errors and exclude real errors" do
        expect(params_errors.size).to eq(2)
      end

    end

    describe "#to_a" do
      it "should return an array with the full messages" do
        expect(params_errors.to_a).to be_kind_of(Array)
        expect(params_errors.to_a).to eq(params_errors.full_messages)
      end
    end

    describe "#to_hash" do
      it "should return a hash with partial messages" do
        expect(params_errors.to_hash(false)).to be_kind_of(Hash)
      end

      it "should return a hash with the full messages" do
        expect(params_errors.to_hash(true)).to be_kind_of(Hash)
        params_errors.to_hash(true).each { |key, msgs|
          msgs.each { |msg|
            expect(msg.downcase).to include(key)
          }
        }
      end
    end

    describe "#to_xml" do

      it "should output XML" do
        expect(real_errors.to_xml.to_s).to include("xml")
      end

    end

    describe "#values" do
      it "should return the error messages without the params" do
        expect(params_errors.values).to be_kind_of(Array)
      end
    end

  end

end

