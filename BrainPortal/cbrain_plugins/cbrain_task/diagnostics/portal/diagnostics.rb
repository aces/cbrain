
#
# CBRAIN Project
#
# Diagnostics model
#
# Original author: Pierre Rioux
#
# $Id$
#

#A subclass of PortalTask to launch diagnostics.
class CbrainTask::Diagnostics < PortalTask

  Revision_info=CbrainFileRevision[__FILE__]

  validate :validate_input_fields

  def self.properties #:nodoc:
    { :use_parallelizer => true }
  end

  def self.default_launch_args #:nodoc:
    {
    :setup_delay           => 0,
    :cluster_delay         => 0,
    :postpro_delay         => 0,

    :setup_crash           => false,
    :cluster_crash         => false,
    :postpro_crash         => false,

    :recover_setup         => true,
    :recover_cluster       => true,
    :recover_postpro       => true,
    :recover_setup_delay   => 10,
    :recover_cluster_delay => 10,
    :recover_postpro_delay => 10,

    :restart_setup         => true,
    :restart_cluster       => true,
    :restart_postpro       => true,
    :restart_setup_delay   => 10,
    :restart_cluster_delay => 10,
    :restart_postpro_delay => 10,

    :num_copies            => 1,
    :crash_will_reset      => true,

    :dp_check_ids          => [],

    :after_form_action     => 'return',
    :after_form_message    => '',

    :refresh_count         => 0,

    :do_validations          => 'Yes',
    :inptest_text_odd_number => "1",
    :inptest_checkbox_1      => "1",
    :inptest_checkbox_2      => "0",
    :inptest_checkbox_3      => "1",
    :inptest_checkbox_4      => "0",
    :inptest_hidden_field    => 'XyZ',
    :inptest_password_field  => '',
    :inptest_radio           => 'first',
    :inptest_textarea        => 'My name is XyZ Jones.',

    :inptest                 => { :deep => 'So deep.' },

    :inptest_select          => '3'
    
    }
  end

  def self.pretty_params_names #:nodoc:
    {
    :inptest_text_odd_number => 'Odd number field',
    :inptest_checkbox_1      => 'Checkboxes',
    :inptest_checkbox_2      => 'Checkboxes',
    :inptest_checkbox_3      => 'Checkboxes',
    :inptest_checkbox_4      => 'Checkboxes',
    :inptest_hidden_field    => 'Hidden field',
    :inptest_password_field  => 'Password field',
    :inptest_radio           => 'WKRP Radio',
    :inptest_textarea        => 'Text area',

    'inptest[deep]'          => 'Deep',

    :inptest_select          => 'Odd selection box'
    }
  end

  def refresh_form #:nodoc:
    params     = self.params || {}
    ref        = (params[:refresh_count] || 0).to_i
    ref += 1
    params[:refresh_count] = ref.to_s
    "Refresh count increased to #{ref}."
  end

  def after_form #:nodoc:
    params     = self.params || {}
    params[:interface_userfile_ids] ||= []

    # Adjust num_copies
    num_copies          = (params[:num_copies] || 1).to_i
    num_copies          = 100 if num_copies > 100
    params[:num_copies] = num_copies

    # Lifecycle checks
    action  = params[:after_form_action]  || ""
    message = params[:after_form_message] || ""

    add_errors_to_check_field(message) if action=~ /field/
    return "" if action == "field"
    return message if action.blank? || action=~ /return|field_ret/i

    ex_class = Class.const_get(action) rescue nil
    if ex_class && ex_class < Exception
      add_errors_to_check_field("Raised #{action}: '#{message}'")
      raise ex_class.new(message)
    end
    raise ScriptError.new("Unparsable check action: '#{action}'")
  end

  def final_task_list #:nodoc:
    params     = self.params || {}
    numfiles   = params[:interface_userfile_ids].size
    num_copies = params[:num_copies]
    desc       = self.description || ""

    task_list = []
    num_copies.times do |i|
      task                       = self.clone
      task.description           = (desc.blank? ? "" : "#{desc} - ") + "Diagnostics with #{numfiles} files" + (num_copies > 1 ? ", copy #{i+1}." : ".")
      task.params[:copy_number]  = (i + 1)
      task_list << task
    end

    task_list
  end

  def untouchable_params_attributes #:nodoc:
    { :copy_number => true, :report_id => true }
  end

  def validate_input_fields #:nodoc:
    params     = self.params || {}

    return true if params[:do_validations].blank?

    odd = params[:inptest_text_odd_number] || "0"
    cb1 = params[:inptest_checkbox_1]      || "0"
    cb2 = params[:inptest_checkbox_2]      || "0"
    cb3 = params[:inptest_checkbox_3]      || "0"
    cb4 = params[:inptest_checkbox_4]      || "0"
    hid = params[:inptest_hidden_field]    || "(Unset)"
    pwd = params[:inptest_password_field]  || ""
    rad = params[:inptest_radio]           || "(Unset)"
    txt = params[:inptest_textarea]        || "(No text)"
    dee = (params[:inptest] || {})[:deep]  || "(No text)"
    sel = params[:inptest_select]          || "0"

    if odd.to_i % 2 == 0
      params_errors.add(:inptest_text_odd_number, "is not odd!")
    end
    if cb1.to_i + cb2.to_i + cb3.to_i + cb4.to_i != 2
      params_errors.add(:inptest_checkbox_1, "are not checked exactly twice!")
      params_errors.add(:inptest_checkbox_2, "are not checked exactly twice!")
      params_errors.add(:inptest_checkbox_3, "are not checked exactly twice!")
      params_errors.add(:inptest_checkbox_4, "are not checked exactly twice!")
    end
    if hid != 'XyZ'
      params_errors.add(:inptest_hidden_field, "has wrong value!")
    end
    if ! pwd.blank? && pwd != 'XyZ'
      params_errors.add(:inptest_password_field, "has wrong password!")
    end
    if rad != 'first' && rad != 'third'
      params_errors.add(:inptest_radio, "is on the wrong channel!")
    end
    if txt !~ /XyZ/
      params_errors.add(:inptest_textarea, "does not contain XyZ!")
    end
    if dee !~ /Deep/i
      params_errors.add('inptest[deep]', "does not contain 'deep'!")
    end
    if sel.to_i % 2 == 0
      params_errors.add(:inptest_select, "is not odd!")
    end
    errors.empty?
  end

  private

  def add_errors_to_check_field(message) #:nodoc:
    message = "No message for field error." if message.blank?
    params_errors.add(:after_form_action, message)
    params_errors.add(:after_form_message, message)
  end

end

