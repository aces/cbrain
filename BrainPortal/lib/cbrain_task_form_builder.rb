require 'action_view/helpers/form_helper'

#
# = Helper Methods For Forms Accessing CbrainTask Params
#
# This class provides helper methods for building forms
# for CbrainTasks; in particular, it provides methods to
# created input fields for pieces of data that will end
# up in the +params+ hash table of the CbrainTask object.
# All methods are meant to act like those in ActionView::Helpers::FormHelper
# but instead of taking the name of an ActiveRecord attribute,
# they take a +paramspath+ as their first argument.
# The +paramspath+ can be a simple symbol or more complex paths
# into the params structure; for instance
#
#    Value for paramspath    CbrainTask's params    Final HTML Tag Variable
#    ----------------------- ---------------------- --------
#    :abc                    params[:abc]           cbrain_task[params][abc]
#    "abc"                   params[:abc]           cbrain_task[params][abc]
#    "myhash[abc]"           params[:myhash][:abc]  cbrain_task[params][myhash][abc]
#    "myarray[3]"            params[:myarray][3]    cbrain_task[params][myarray][3]
#    "anarray[]"             params[:anarray]       cbrain_task[params][anarray][]
# 
# Basically, when generating the input tags, the paramspath is
# automatically transformed into the string returned by calling
# the String or Symbol method to_la() on it. The final HTML
# variable name for :abc will be "cbrain_task[params][abc]",
# for instance.
#
# The default value for each input tag will be what is found
# in the params hash of the current CbrainTask object used by
# the form.
#
# == Examples
#
# Assuming we start with a CbrainTask initialized
# with these parameters:
#
#    params = { :comment  => "hi!",
#               :do_it    => 1,
#               :alist    => [ "one", "two", "three" ],
#               :hidethis => "secret",
#               :alpha    => { :a => 1, :b => 2 }
#             }
#
# Then this code:
#
#    <%= form.params_text_field   :comment   %>
#    <%= form.params_check_box    :do_it     %>
#    <%= form.params_text_field   "alist[1]" %>
#    <%= form.params_hidden_field :hidethis  %>
#    <%= form.params_text_field   "alpha[b]" %>
#
# Will generate:
#
#    <input type="text"     name="cbrain_task[params][comment]"  value="hi!">
#    <input type="checkbox" name="cbrain_task[params][do_it]"    value="1" checked>
#    <input type="hidden"   name="cbrain_task[params][do_it]"    value="0">
#    <input type="text"     name="cbrain_task[params][alist][1]" value="two">
#    <input type="hidden"   name="cbrain_task[params][hidethis]" value="secret">
#    <input type="text"     name="cbrain_task[params][alpha][b]" value="2">
#
# Note that two input fields are created by params_check_box() and
# that the default checked and unchecked values are "1" and "0".
class CbrainTaskFormBuilder < ActionView::Helpers::FormBuilder

  Revision_info="$Id$"

  #########################################################
  # Implementation note: we cheat by calling the
  # standard FormBuilder methods and giving them
  # the method "nil?", which always return false,
  # but providing anyway the values, id and names
  # for the input field already prepared in the options
  # hash.
  #########################################################

  # Creates a text input field for the CbrainTask parameter
  # identified by +paramspath+. See the module
  # ActionView::Helpers::FormHelper, but keep in mind
  # the target for the input field is an entry in the
  # params hash of the CbrainTask, not one of its attribute.
  def params_text_field(paramspath, options = {})
    pseudo_method = create_access_method(paramspath)
    text_field(pseudo_method, params_common_options(paramspath,options))
  end

  # Creates a check box input field for the CbrainTask parameter
  # identified by +paramspath+. See the module
  # ActionView::Helpers::FormHelper, but keep in mind
  # the target for the input field is an entry in the
  # params hash of the CbrainTask, not one of its attribute.
  #
  # Be careful with check_box tags and their true/false values!
  # See the doc in the module above.
  def params_check_box(paramspath, options = {}, checked_value = "1", unchecked_value = "0")
    new_options = params_common_options(paramspath,options)
    found_value = new_options[:value]
    if found_value.blank? || (found_value.is_a?(Numeric) && found_value == 0) || (found_value.is_a?(String) && found_value == "0")
      new_options[:value]   = unchecked_value
      new_options.delete(:checked)
    else
      new_options[:value]   = checked_value
      new_options[:checked] = true
    end
    pseudo_method = create_access_method(paramspath)
    check_box(pseudo_method, new_options, checked_value, unchecked_value)
  end

  # Creates a hidden input field for the CbrainTask parameter
  # identified by +paramspath+. See the module
  # ActionView::Helpers::FormHelper, but keep in mind
  # the target for the input field is an entry in the
  # params hash of the CbrainTask, not one of its attribute.
  def params_hidden_field(paramspath, options = {})
    pseudo_method = create_access_method(paramspath)
    hidden_field(pseudo_method, params_common_options(paramspath,options))
  end

  # Creates a password input field for the CbrainTask parameter
  # identified by +paramspath+. See the module
  # ActionView::Helpers::FormHelper, but keep in mind
  # the target for the input field is an entry in the
  # params hash of the CbrainTask, not one of its attribute.
  def params_password_field(paramspath, options = {})
    pseudo_method = create_access_method(paramspath)
    password_field(pseudo_method, params_common_options(paramspath,options))
  end

  # Creates a radio button input field for the CbrainTask parameter
  # identified by +paramspath+. See the module
  # ActionView::Helpers::FormHelper, but keep in mind
  # the target for the input field is an entry in the
  # params hash of the CbrainTask, not one of its attribute.
  def params_radio_button(paramspath, tag_value, options = {})
    pseudo_method = create_access_method(paramspath)
    radio_button(pseudo_method, tag_value, params_common_options(paramspath,options))
  end

  # Creates a text aread input field for the CbrainTask parameter
  # identified by +paramspath+. See the module
  # ActionView::Helpers::FormHelper, but keep in mind
  # the target for the input field is an entry in the
  # params hash of the CbrainTask, not one of its attribute.
  def params_text_area(paramspath, options = {})
    pseudo_method = create_access_method(paramspath)
    text_area(pseudo_method, params_common_options(paramspath,options))
  end

  # This provides a replacement for the label() method
  # of the default form builder.
  def params_label(paramspath, *args)
    id = paramspath.to_la_id.sub(/^cbrain_task_/,"")
    args.unshift(paramspath.to_s.humanize) if args.size == 0
    label(id, *args)
  end

  private

  def params_common_options(paramspath, options = {}) #:nodoc:
    added_path    = paramspath.to_la
    added_id      = paramspath.to_la_id
    added_options = options.dup.merge( {
                      :name  => added_path,  # input tag variable name
                      :id    => added_id
                    } )
    unless added_options.has_key?(:value) || added_options.has_key?("value")
      current_value = @object.params_path_value(paramspath) # value in params hash
      current_value = "" unless [ Numeric, String, Symbol, TrueClass, FalseClass ].detect { |k| current_value.is_a?(k) }
      added_options[:value] = current_value
    end
    added_options
  end

  def create_access_method(paramspath) #:nodoc:
     pseudo_method = paramspath.to_la_id.to_sym
     return pseudo_method if @object.respond_to?(pseudo_method)
     @object.class_eval "
       def #{pseudo_method}
         self.params_path_value('#{paramspath}')
       end
     "
     pseudo_method
  end

end # class CbrainTaskFormBuilder

