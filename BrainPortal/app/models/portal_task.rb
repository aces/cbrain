
#
# CBRAIN Project
#
# CbrainTask models as a Web Interface
#
# Original author: Pierre Rioux
#
# $Id$
#

# This subclass of CbrainTask provides the methods and developer API
# for deploying CbrainTasks on the BrainPortal side.
#
# See the documentation in CbrainTask.txt for more information.
class PortalTask < CbrainTask

  Revision_info="$Id$"

  # This associate one of the keywords we use in the interface
  # to a task status that 'implements' the operation (basically,
  # simply setting the task's status to the value modifies the
  # task's state). This is used in the tasks controller
  # for issuing 'alter_tasks' remote commands.
  OperationToNewStatus = {
    # HTML page keyword   =>  New status
    #------------------   -----------------
    "hold"                => "On Hold",
    "release"             => "Queued",
    "suspend"             => "Suspended",
    "resume"              => "On CPU",
    "terminate"           => "Terminated",
    "recover"             => "Recover",
    "restart_setup"       => "Restart Setup",
    "restart_cluster"     => "Restart Cluster",
    "restart_postprocess" => "Restart PostProcess",
    "duplicate"           => "Duplicate"
  }

  # In order to optimize the set of state transitions
  # allowed in the tasks, this hash list when we can
  # attempt to change the tasks states. This is
  # used by the tasks controller so as not to send
  # messages to Bourreaux to do stuff on tasks that
  # are not ready for it anyway.
  AllowedOperations = { # destroy is handled differently and separately
    # Current                          =>   List of states we can change to
    #--------------------------------  ------------------------------
    "Queued"                           => [ "Duplicate", "Terminated", "On Hold"   ],
    "On Hold"                          => [ "Duplicate", "Terminated", "Queued"    ],
    "On CPU"                           => [ "Duplicate", "Terminated", "Suspended" ],
    "Suspended"                        => [ "Duplicate", "Terminated", "On CPU"    ],
    "Failed To Setup"                  => [ "Duplicate", "Recover" ],
    "Failed On Cluster"                => [ "Duplicate", "Recover" ],
    "Failed To PostProcess"            => [ "Duplicate", "Recover" ],
    "Failed Setup Prerequisites"       => [ "Duplicate", "Recover" ],
    "Failed PostProcess Prerequisites" => [ "Duplicate", "Recover" ],
    "Terminated"                       => [ "Duplicate" ],
    "Completed"                        => [ "Duplicate", "Restart Setup", "Restart Cluster", "Restart PostProcess" ]
    # Other transitions are not used by the interface,
    # as they cannot be triggered by the user. For
    # instance, "On CPU" to "Data Ready", which is
    # handled by the Bourreau Workers.
  }

  #######################################################
  # Task Launch API
  #######################################################

  # Special boolean properties of your task, returned as a
  # hash table. Used by CBRAIN rendering code to control
  # default elements. Advanced feature. The defaults
  # for all properties should be 'false' so that subclass
  # only have to explicitely set the special properties
  # that they want 'true' (since nil is also false).
  def self.properties
    {
       :no_submit_button                   => false, # view will not automatically have a submit button
       :i_save_my_task_in_after_form       => false, # used by validation code for detected coding errors
       :i_save_my_tasks_in_final_task_list => false, # used by validation code for detected coding errors
       :no_presets                         => false  # view will not contain the preset load/save panel
    }
  end

  # This method should return a simple hash table
  # with the default launch arguments for your task;
  # the content of your CbrainTask's :params
  # attribute will be initialized to be a perfect
  # copy of this hash table.
  def self.default_launch_args
    {}
  end

  # This method will be called before the view for the
  # task object is rendered. It doesn't have to do
  # anything but it can initalize some parameters based
  # on the list of interface_userfile_ids for instance.
  #
  # If the method returns a non-empty string, this
  # will be shown as a message.
  def before_form
    ""
  end
  
  # This method is called after the user has clicked
  # to submit the form for the task, but before it
  # is launched. Just like before_form(), it doesn't have
  # to do anything but it can initalize some parameters based
  # on the list of interface_userfile_ids for instance.
  #
  # If the method returns a non-empty string, this
  # will be shown as a message.
  def after_form
    ""
  end

  # This method returns the final list of fully completed
  # CbrainTask objects that will be launched; the returned
  # value must be an array of CbrainTask that may or may not
  # include the current object. The default value is simply
  # an array containing +self+.
  def final_task_list
    [ self ]
  end

  # This method can be called to do any processing you
  # feel like doing after the final_task_list has been
  # saved; the task list with the saved objects will be
  # provided in argument.
  #
  # If the method returns a non-empty string, this
  # will be shown as a message.
  def after_final_task_list_saved(task_list)
    ""
  end

  # This method should identify which attributes
  # in params are not to be modified during
  # a task edit session. The returned value of the method
  # should simply be a hash table where the keys are
  # the untouchable attributes and the values are true.
  # By default the content of the hash is
  #
  #    { :interface_userfile_ids => true }
  #
  # The values in this default hash WILL be
  # added to whatever other values are returned
  # by overriden versions of this method (in other
  # words, even if you don't explicitely include
  # :interface_userfile_ids in the hash, it will
  # be considered).
  def untouchable_params_attributes
    { :interface_userfile_ids => true }
  end



  ######################################################
  # Wrappers around official API
  # These are not to be called by subtasks nor
  # overridden; they're meant to intercept errors and
  # and make sure that task programmers properly
  # return meaningful values for their implementation
  # of API methods.
  ######################################################

  def self.wrapper_default_launch_args #:nodoc:
    begin
      ret = self.default_launch_args
      cb_error "Coding error: method default_launch_args() for #{self.class} did not return a hash?!?" unless
        ret.is_a?(Hash)
      return ret
    rescue CbrainError, CbrainNotice => cber
      raise cber
    rescue => other
      cber = ScriptError.new("Coding error: method default_launch_args() for #{self.class} raised an exception: #{other.class}: #{other.message}")
      cber.set_backtrace(other.backtrace.dup)
      raise cber
    end
  end

  def wrapper_before_form #:nodoc:
    begin
      was_new = self.new_record?
      ret = self.before_form
      cb_error "Coding error: method before_form() for #{self.class} did not return a string?!?" unless
        ret.is_a?(String)
      cb_error "Coding error: method before_form() for #{self.class} SAVED its object!" if was_new && ! self.new_record?
      return ret
    rescue CbrainError, CbrainNotice => cber
      raise cber
    rescue => other
      cber = ScriptError.new("Coding error: method before_form() for #{self.class} raised an exception: #{other.class}: #{other.message}")
      cber.set_backtrace(other.backtrace.dup)
      raise cber
    end
  end

  def wrapper_after_form #:nodoc:
    begin
      was_new = self.new_record?
      ret = self.after_form
      cb_error "Coding error: method after_form() for #{self.class} did not return a string?!?" unless
        ret.is_a?(String)
      cb_error "Coding error: method after_form() for #{self.class} SAVED its object!" if
        (was_new && ! self.new_record?) && ! self.class.properties[:i_save_my_task_in_after_form]
      return ret
    rescue CbrainError, CbrainNotice => cber
      raise cber
    rescue => other
      cber = ScriptError.new("Coding error: method after_form() for #{self.class} raised an exception: #{other.class}: #{other.message}")
      cber.set_backtrace(other.backtrace.dup)
      raise cber
    end
  end

  def wrapper_final_task_list #:nodoc:
    begin
      ret = self.final_task_list
      cb_error "Coding error: method final_task_list() for #{self.class} did not return an array?!?" unless
        ret.is_a?(Array)
      cb_error "Coding error: method final_task_list() for #{self.class} returned an array but it doesn't contain CbrainTasks?!?" if
        ret.detect { |t| ! t.is_a?(CbrainTask) }
      if ! self.class.properties[:i_save_my_tasks_in_final_task_list]
        cb_error "Coding error: method final_task_list() for #{self.class} SAVED one or more of its tasks?!?" if
          ret.detect { |t| ! t.new_record? }
      end
      return ret
    rescue CbrainError, CbrainNotice => cber
      raise cber
    rescue => other
      cber = ScriptError.new("Coding error: method final_task_list() for #{self.class} raised an exception: #{other.class}: #{other.message}")
      cber.set_backtrace(other.backtrace.dup)
      raise cber
    end
  end

  def wrapper_after_final_task_list_saved(tasklist) #:nodoc:
    begin
      ret = self.after_final_task_list_saved(tasklist)
      cb_error "Coding error: method after_final_task_list_saved() for #{self.class} did not return a string?!?" unless
        ret.is_a?(String)
      return ret
    rescue CbrainError, CbrainNotice => cber
      raise cber
    rescue => other
      cber = ScriptError.new("Coding error: method after_final_task_list_saved() for #{self.class} raised an exception: #{other.class}: #{other.message}")
      cber.set_backtrace(other.backtrace.dup)
      raise cber
    end
  end

  # Used internally to add ALWAYS PRESENT attributes.
  def wrapper_untouchable_params_attributes #:nodoc:
    att = self.untouchable_params_attributes || {}
    ext = att.merge(
      :interface_userfile_ids => true
    )
    return ext
  end



  #######################################################
  # Methods For CbrainTask Form Builder
  #######################################################

  def params_path_value(paramspath) #:nodoc:
    params     = self.params || {}
    stringpath = paramspath.to_s
    foundvalue = params
    key        = ""
    while stringpath != ""
      break unless stringpath =~ /^(\[?([\w\.\-]+)\]?)/
      brackets = Regexp.last_match[1]   # "[abcdef]"
      key      = Regexp.last_match[2]   # "abcdef"
      stringpath = stringpath[brackets.size .. -1]
      if foundvalue.is_a?(Hash)
        foundvalue = foundvalue[key.to_sym] || foundvalue[key]
      elsif foundvalue.is_a?(Array) && key =~ /^\d+$/
        foundvalue = foundvalue[key.to_i]
      else
        cb_error "Can't access params structure for '#{paramspath}' (stopped at '#{key}' with current structure a '#{foundvalue.class}'."
      end
      break if foundvalue.nil?
    end
    cb_error "Can't find intermediate params structure for '#{paramspath}' (stopped at '#{key}' for '#{foundvalue.inspect}')" if stringpath != "" && stringpath != "[]"
    foundvalue
  end

end

# Patch: pre-load all model files for the subclasses
Dir.chdir(File.join(RAILS_ROOT, "app", "models", "cbrain_task")) do
  Dir.glob("*.rb").each do |model|
    model.sub!(/.rb$/,"")
    unless CbrainTask.const_defined? model.classify
      require_dependency "cbrain_task/#{model}.rb"
      #puts ">>>> #{model} #{model.classify}"
    end
  end
end

