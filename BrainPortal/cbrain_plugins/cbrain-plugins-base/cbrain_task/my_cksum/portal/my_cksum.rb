
# A subclass of CbrainTask to launch MyCksum.
# This task was created by following exactly
# the New Cbrain Task Tutorial on the CBRAIN Wiki,
# as of May 6, 2015.
#
# Extra comments that are normally generated automatically
# by the rake generator task have been left as-is.
class CbrainTask::MyCksum < PortalTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  ################################################################
  # For full documentation on how to write CbrainTasks,
  # read the CbrainTask Programmer Guide.
  #
  # The basic API consists in three methods that you need to
  # override:
  #
  #   self.default_launch_args()
  #   before_form()
  #   after_form()
  #
  # The advanced API consists in four more methods, needed only
  # for more complex cases:
  #
  #   self.properties()
  #   final_task_list()
  #   after_final_task_list_saved(tasklist)
  #   untouchable_params_attributes()
  #
  # The advanced API is not included in this template since
  # you did not run the generator with the option --advanced.
  #
  # Please remove all the comment blocks before committing
  # your code. Provide proper RDOC comments just before
  # each method if you want to document them, but note
  # that normally all normal API methods are #:nodoc: anyway.
  ################################################################




  ################################################################
  # METHOD: self.default_launch_args()
  ################################################################
  # This method will be called before the form for your task is
  # rendered. It should return a hash table. This hash table will
  # be copied as-is into the task's "params" hash table.
  ################################################################

  # RDOC comments here, if you want, although the method
  # is created with #:nodoc: in this template.
  def self.default_launch_args #:nodoc:
    {
      # all params are strings if they are shown in the web page
      :output_file_prefix  => "ck_",
      :an_odd_number       => "7",    # shows in form if we run version 2.0.0 or greater
      :struct_with_day_and_month => {
        :day   => 3,
        :month => 'Jan',
      }
    }
  end

  def self.pretty_params_names #:nodoc:
    {
      :output_file_prefix                => 'prefix for the reports',
      :an_odd_number                     => 'odd number',
      "struct_with_day_and_month[day]"   => "day of month",
      "struct_with_day_and_month[month]" => "month name",
    }
  end


  ################################################################
  # METHOD: before_form()
  ################################################################
  # This method will be called before the form for your task is
  # rendered. For new tasks, the task object's "params" hash table
  # will contain the list of IDs selected in the userfile manager:
  #
  #   params[:interface_userfile_ids] = [ id1, id2...]
  #
  # You can filter and validate the IDs here.
  # You're free to add as much supplemental information as
  # you want in the params hash table too, but remember that
  # the form will ONLY send you back (in after_form()) what
  # is also covered by input tags in the view file.
  #
  # You must not save your new task object here.
  #
  # The method should return a string to inform the user of any
  # changes or notifications, and raise an exception for any
  # fatal errors.
  #
  # This method is also called when editing an existing task's
  # parameters; you can detect when this happens because the
  # task object will not be new (it will return false for
  # the method new_record()).
  ################################################################

  # RDOC comments here, if you want, although the method
  # is created with #:nodoc: in this template.
  def before_form #:nodoc:
    ids = self.params[:interface_userfile_ids].presence || [] # an array of IDs
    numfound = SingleFile.where(:id => ids).count # ActiveRecord makes sure the subclasses match
    cb_error "All selected files must be simple files." if numfound != ids.size
    return "" # all ok
  end



  ################################################################
  # METHOD: after_form()
  ################################################################
  # This method will be called after the form for your task has
  # been submitted by the user. The content of the task's attributes
  # (like :bourreau_id, :description, etc) will be filled in
  # by selection box already provided by the form. The params
  # hash table will contain the values of input tags contained
  # in the view (provided their variable names are properly
  # created with cbrain task form helpers). Note that any other
  # pieces of information stored in params() during before_form()
  # will be lost unless such input tags are present to preserve
  # them.
  #
  # You must not save your new task object here.
  #
  # The method should return a string to inform the user of any
  # changes or notifications, and raise an exception for any
  # fatal errors.
  #
  # This method is also called when editing an existing task's
  # parameters; you can detect when this happens because the
  # task object will not be new (it will return false for
  # the method new_record()).
  #
  # It's possible to design simple tasks where this method
  # is not necessary at all, for instance if none of the values
  # supplied using the form need any form of validation (but still,
  # be careful of injection attacks!).
  ################################################################

  def refresh_form #:nodoc:
    random_month = [ 'Jan', 'Feb', 'Mar', 'Apr' ].sample
    self.params[:struct_with_day_and_month][:month] = random_month
    ""  # all OK
  end

  # RDOC comments here, if you want, although the method
  # is created with #:nodoc: in this template.
  def after_form #:nodoc:
    return "" unless self.tool_config.is_at_least_version("2.0.0")
    odd_num = params[:an_odd_number].presence
    if odd_num.blank? || (odd_num.to_i % 2 != 1)
      params_errors.add(:an_odd_number, "is not odd, please enter an odd number.")
    end
    params_error.add(:output_file_prefix, "must be a simple prefix with no spaces") unless
      params[:output_file_prefix] =~ /^\w+$/
    "" # all ok
  end

  def final_task_list
    ids = self.params[:interface_userfile_ids]
    tasklist = []
    ids.each do |id|
       newtask = self.dup  # duplicate the whole task
       newtask.params[:interface_userfile_ids] = [ id ] # replace the list by a new one with a single ID
       tasklist << newtask
    end
    tasklist
  end

end

