
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
    }
  end

  def after_form #:nodoc:
    params     = self.params
    params[:interface_userfile_ids] ||= []

    # Adjust num_copies
    num_copies          = (params[:num_copies] || 1).to_i
    num_copies          = 100 if num_copies > 100
    params[:num_copies] = num_copies
    ""
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

end

