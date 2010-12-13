
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

  Revision_info="$Id$"

  validate :validate_input_fields

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

    :after_form_action     => 'return',
    :after_form_message    => '',

    :refresh_count         => 0,

    :inptest_text_odd_number => "1",
    :inptest_checkbox_1      => "1",
    :inptest_checkbox_2      => "0",
    :inptest_checkbox_3      => "1",
    :inptest_checkbox_4      => "0",
    :inptest_hidden_field    => 'XyZ',
    :inptest_password_field  => '',
    :inptest_radio           => 'first',
    :inptest_textarea        => 'My name is XyZ Jones.'
    
    }
  end

  def refresh_form #:nodoc:
    params     = self.params
    ref        = (params[:refresh_count] || 0).to_i
    ref += 1
    params[:refresh_count] = ref.to_s
    "Refresh count increased to #{ref}."
  end

  def after_form #:nodoc:
    params     = self.params
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
    params     = self.params
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
    params     = self.params

    odd = params[:inptest_text_odd_number] || "0"
    cb1 = params[:inptest_checkbox_1]      || "0"
    cb2 = params[:inptest_checkbox_2]      || "0"
    cb3 = params[:inptest_checkbox_3]      || "0"
    cb4 = params[:inptest_checkbox_4]      || "0"
    hid = params[:inptest_hidden_field]    || "(Unset)"
    pwd = params[:inptest_password_field]  || ""
    rad = params[:inptest_radio]           || "(Unset)"
    txt = params[:inptest_textarea]        || "(No text)"

    if odd.to_i % 2 == 0
      errors.add(:inptest_text_odd_number.to_la_id,"is not odd!")
    end
    if cb1.to_i + cb2.to_i + cb3.to_i + cb4.to_i != 2
      errors.add(:inptest_checkbox_1.to_la_id,"must check exactly two!")
      errors.add(:inptest_checkbox_2.to_la_id,"must check exactly two!")
      errors.add(:inptest_checkbox_3.to_la_id,"must check exactly two!")
      errors.add(:inptest_checkbox_4.to_la_id,"must check exactly two!")
    end
    if hid != 'XyZ'
      errors.add(:inptest_hidden_field.to_la_id,"has wrong value!")
    end
    if ! pwd.blank? && pwd != 'XyZ'
      errors.add(:inptest_password_field.to_la_id,"has wrong password!")
    end
    if rad != 'first' && rad != 'third'
      errors.add(:inptest_radio.to_la_id,"is on wrong channel!")
    end
    if txt !~ /XyZ/
      errors.add(:inptest_textarea.to_la_id,"does not contain XyZ!")
    end
    errors.empty?
  end

  private

  def add_errors_to_check_field(message)
    message = "No message for field error." if message.blank?
    errors.add(:after_form_action.to_la_id, message)
    errors.add(:after_form_message.to_la_id, message)
  end
end

