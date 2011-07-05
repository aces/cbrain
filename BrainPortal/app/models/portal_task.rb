
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

  Revision_info=CbrainFileRevision[__FILE__]

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
    "duplicate"           => "Duplicated"
  }

  # In order to optimize the set of state transitions
  # allowed in the tasks, this hash list when we can
  # attempt to change the tasks states. This is
  # used by the tasks controller so as not to send
  # messages to Bourreaux to do stuff on tasks that
  # are not ready for it anyway.
  AllowedOperations = { # 'Destroy' is handled differently and separately

    #===============================================================================
    # Active states
    #===============================================================================

    # Current                          => List of states we can change to
    #--------------------------------  ---------------------------------------------
    "Queued"                           => [ "Duplicated", "Terminated", "On Hold"   ],
    "On Hold"                          => [ "Duplicated", "Terminated", "Queued"    ],
    "On CPU"                           => [ "Duplicated", "Terminated", "Suspended" ],
    "Suspended"                        => [ "Duplicated", "Terminated", "On CPU"    ],

    #===============================================================================
    # Passive states
    #===============================================================================

    # Current                          => List of states we can change to
    #--------------------------------  ---------------------------------------------
    "Failed To Setup"                  => [ "Duplicated", "Recover" ],
    "Failed On Cluster"                => [ "Duplicated", "Recover" ],
    "Failed To PostProcess"            => [ "Duplicated", "Recover" ],
    "Failed Setup Prerequisites"       => [ "Duplicated", "Recover" ],
    "Failed PostProcess Prerequisites" => [ "Duplicated", "Recover" ],
    "Terminated"                       => [ "Duplicated", "Restart Setup" ],
    "Completed"                        => [ "Duplicated", "Restart Setup", "Restart Cluster", "Restart PostProcess" ],
    "Duplicated"                       => [ "Restart Setup" ],

    #===============================================================================
    # Killed ruby code... (bourreau will check it's more than 8 hours ago)
    #===============================================================================

    # Current                          => List of states we can change to
    #--------------------------------  ---------------------------------------------
    "Setting Up"                       => [ "Duplicated", "Terminated" ],
    "Post Processing"                  => [ "Duplicated", "Terminated" ],
    "Restarting Setup"                 => [ "Duplicated", "Terminated" ],
    "Restarting Cluster"               => [ "Duplicated", "Terminated" ],
    "Restarting PostProcess"           => [ "Duplicated", "Terminated" ],
    "Recovering Setup"                 => [ "Duplicated", "Terminated" ],
    "Recovering Cluster"               => [ "Duplicated", "Terminated" ],
    "Recovering PostProcess"           => [ "Duplicated", "Terminated" ],

    "Standby"                          => [],
    "Configured"                       => [],
    "Preset"                           => []   # kind of dummy last entry

    # Other transitions are not used by the interface,
    # as they cannot be triggered by the user. For
    # instance, "On CPU" to "Data Ready", which is
    # handled by the Bourreau Workers.
  }



  ##################################################################
  # Core Object Methods
  ##################################################################

  # Automatically register the task's version when new() is invoked.
  def initialize(arguments = {}) #:nodoc:
    super(arguments)
    baserev = Revision_info
    subrev  = self.revision_info
    self.addlog("#{baserev.svn_id_file} rev. #{baserev.svn_id_rev}")
    self.addlog("#{subrev.svn_id_file} rev. #{subrev.svn_id_rev}")
  end

  # Backwards compatibility auto adaptation:
  # if a task's code is extended to incldue new parameters,
  # then this will re-insert their default values
  # into the params[] hash.
  #
  # This used to be an 'after_find' callback, but it was
  # much too expensive when a large number of tasks were
  # reloaded.
  def add_new_params_defaults #:nodoc:
    params = self.params ||  {}
    mydef  = self.class.default_launch_args || {}
    mydef.each do |k,v|
      next if params.has_key?(k)
      if v.is_a?(String) || v.is_a?(Array) || v.is_a?(Hash)
         params[k] = v.clone
      else
         params[k] = v
      end
    end
    self.params = params
  end



  #######################################################
  # Task Launch API
  #######################################################

  # Special boolean properties of your task, returned as a
  # hash table. Used by CBRAIN rendering code to control
  # default elements. Advanced feature. The defaults
  # for all properties are'false' so that subclass
  # only have to explicitely set the special properties
  # that they want 'true' (since nil is also false).
  def self.properties
    {
       :no_submit_button                   => false, # view will not automatically have a submit button
       :i_save_my_task_in_after_form       => false, # used by validation code for detected coding errors
       :i_save_my_tasks_in_final_task_list => false, # used by validation code for detected coding errors
       :no_presets                         => false, # view will not contain the preset load/save panel
       :use_parallelizer                   => false  # true or fixnum: turns on parallelization
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

  # This method should return a hash mapping the raw
  # IDs of your task's parameters (as used with the
  # CbrainTaskFormBuilder helper methods) to prettier
  # names that will be used for error messages. For
  # instance, if your form defines a field like this:
  #
  #   <%= params_text_field :rand_seed %>
  #
  # and you validate it in your model with
  #
  #   params_errors.add(:rand_seed, "must be odd")
  #
  # then you can make sure the error message is
  # prettier by making this method return
  #
  #    :rand_seed => 'The random seed number'
  #
  # as one of the elements of the hash.
  # Keys of the hash can be arbitrary paramspaths:
  #
  #    'employee[name]' => 'The name of the employee'
  #
  # This hash is used by the PortalTask's own class
  # method human_attribute_name().
  def self.pretty_params_names
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

  # This method will be called if the user clicks
  # on a button labelled /Refresh/ when creating
  # a new task or editing an existing one. It
  # doesn't have to do anything, but usually it's
  # convenient when we want to dynamicallty adjust
  # some of the form elements.
  def refresh_form
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
  # be in there).
  def untouchable_params_attributes
    { :interface_userfile_ids => true }
  end

  # Similarly to untouchable_params_attributes, this method
  # should return a hash where the keys identify
  # params attributes that should NOT be reloaded when
  # the user loads a preset. The default is an empty hash.
  def unpresetable_params_attributes
    {}
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
      raise ScriptError.new("Coding error: method default_launch_args() for #{self.class} did not return a hash?!?") unless
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
      raise ScriptError.new("Coding error: method before_form() for #{self.class} did not return a string?!?") unless
        ret.is_a?(String)
      raise ScriptError.new("Coding error: method before_form() for #{self.class} SAVED its object!") if was_new && ! self.new_record?
      return ret
    rescue CbrainError, CbrainNotice => cber
      raise cber
    rescue => other
      cber = ScriptError.new("Coding error: method before_form() for #{self.class} raised an exception: #{other.class}: #{other.message}")
      cber.set_backtrace(other.backtrace.dup)
      raise cber
    end
  end

  def wrapper_refresh_form #:nodoc:
    begin
      was_new = self.new_record?
      ret = self.refresh_form
      raise ScriptError.new("Coding error: method refresh_form() for #{self.class} did not return a string?!?") unless
        ret.is_a?(String)
      raise ScriptError.new("Coding error: method refresh_form() for #{self.class} SAVED its object!") if was_new && ! self.new_record?
      return ret
    rescue CbrainError, CbrainNotice => cber
      self.errors.add(:base, "#{cber.class.to_s.sub(/Cbrain/,"")} in form: #{cber.message}\n")
      return ret || ""
    rescue => other
      cber = ScriptError.new("Coding error: method refresh_form() for #{self.class} raised an exception: #{other.class}: #{other.message}")
      cber.set_backtrace(other.backtrace.dup)
      raise cber
    end
  end

  def wrapper_after_form #:nodoc:
    begin
      was_new = self.new_record?
      ret = self.after_form
      raise ScriptError.new("Coding error: method after_form() for #{self.class} did not return a string?!?") unless
        ret.is_a?(String)
      raise ScriptError.new("Coding error: method after_form() for #{self.class} SAVED its object!") if
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
      list_plus_message = self.final_task_list  # [t,t,t]     OR     [ [t,t,t], message ]
      if list_plus_message.size == 2 && list_plus_message[0].is_a?(Array) # when an optional message is returned
        ret,message = list_plus_message
      else # standard case
        ret = list_plus_message
        message = nil
      end
      raise ScriptError.new("Coding error: method final_task_list() for #{self.class} did not return an array?!?") unless
        ret.is_a?(Array)
      raise ScriptError.new("Coding error: method final_task_list() for #{self.class} returned an array but it doesn't contain CbrainTasks?!?") if
        ret.detect { |t| ! t.is_a?(CbrainTask) }
      if ! self.class.properties[:i_save_my_tasks_in_final_task_list]
         raise ScriptError.new("Coding error: method final_task_list() for #{self.class} SAVED one or more of its tasks?!?") if
          ret.detect { |t| ! t.new_record? }
      end
      return ret,message
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
      raise ScriptError.new("Coding error: method after_final_task_list_saved() for #{self.class} did not return a string?!?") unless
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

  # Used internally to specify params attributes
  # that should not be modified when reloading a preset.
  def wrapper_unpresetable_params_attributes #:nodoc:
    att = self.unpresetable_params_attributes || {}
    return att
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

  # Wrapper class around the ActiveRecord errors() method;
  # this class answers to the same methods as the errors
  # object but its 'attributes' are actually paramspaths.
  # See the Rails classes ActiveRecord::Validations and
  # ActiveRecord::Errors for more information.
  class ParamsErrors
    attr_writer :real_errors

    def on(paramspath) #:nodoc:
      @real_errors.on(paramspath.to_la_id)
    end

    def [](paramspath) #:nodoc:
      @real_errors.on(paramspath.to_la_id)
    end

    def add(paramspath,*args) #:nodoc:
      @real_errors.add(paramspath.to_la_id,*args)
    end

    def add_on_blank(paramspaths,*args) #:nodoc:
      @real_errors.add_on_blank(paramspaths.map(&:to_la_id),*args)
    end

    def add_on_empty(paramspaths,*args) #:nodoc:
      @real_errors.add_on_empty(paramspaths.map(&:to_la_id),*args)
    end

    def add_to_base(*args) #:nodoc:
      @real_errors.add_to_base(*args)
    end

    def size #:nodoc:
      @real_errors.size
    end

    def count #:nodoc:
      @real_errors.size
    end

    def length #:nodoc:
      @real_errors.size
    end

    def clear #:nodoc:
      @real_errors.clear
    end

    def each(&block) #:nodoc:
      @real_errors.each(&block)
    end

    def each_full(&block) #:nodoc:
      @real_errors.each_full(&block)
    end

    def empty? #:nodoc:
      @real_errors.empty?
    end

    def full_messages(*args) #:nodoc:
      @real_errors.full_messages(*args)
    end

    def generate_message(paramspath,*args) #:nodoc:
      @real_errors.generate_message(paramspaths.to_la_id,*args)
    end

    def invalid?(paramspath) #:nodoc:
      @real_errors.invalid?(paramspath.to_la_id)
    end

    def on_base #:nodoc:
      @real_errors.on_base
    end

    def to_xml(*args) #:nodoc:
      @real_errors.to_xml(*args)
    end

  end

  # Returns the equivalent of the 'errors' object for the
  # task, but where the attributes are in fact paramspath
  # values for the task's params[] hash. This works much like
  # the standard ActiveRecord::Errors class. This is used for
  # validating the task's params. For instance:
  #
  #   params = task.params || {}
  #   name   = params[:name]
  #   age    = params[:info][age]
  #   task.params_errors.add(:name, "is blank!") if name.blank?
  #   task.params_errors.add('info[age]', "is not set!") if age.blank?
  #
  # This would result in the two error messages
  #
  #   name is blank!
  #   info age is not set!
  #
  # In conjunction with pretty_params_names(), the error messages
  # can be made more elegant by giving better names to the
  # parameters.
  def params_errors
    return @params_errors_cache if @params_errors_cache
    @params_errors_cache = ParamsErrors.new
    @params_errors_cache.real_errors = self.errors
    @params_errors_cache
  end

  # This method returns a 'pretty' name for a params attributes.
  # This implementation will try to look up a hash table returned
  # by the class method pretty_params_names() first, so an
  # easy way to provide beautiful names for your parameters
  # is to make pretty_params_names() return such a hash.
  # Otherwise, if the attribute starts with 'cbrain_task_params_'
  # (like ActiveRecord thinks the params attributes are named)
  # it will remove that part and return the rest. And otherwise,
  # it invokes the superclass method.
  def self.human_attribute_name(attname)
    prettyhash = self.pretty_params_names || {}
    shortname = (attname =~ /^cbrain_task_params_/) ? attname.sub(/^cbrain_task_params_/,"") : nil
    # We try to guess many ways that the task programmer could have
    # stored his 'pretty' names in the hash, including forgetting to call
    # to_la_id() on the keys.
    if prettyhash.size > 0
       extended = prettyhash.dup
       prettyhash.each do |att,name| # extend it with to_la_id automatically...
         next unless att.is_a?(String) && (att.index('[') || -1 ) >= 0
         id_att = att.to_la_id
         next if extended.has_key?(id_att)
         extended[id_att] = name
       end
       return extended[attname]        if extended.has_key?(attname)
       return extended[attname.to_sym] if extended.has_key?(attname.to_sym)
       if shortname
         return extended[shortname]        if extended.has_key?(shortname)
         return extended[shortname.to_sym] if extended.has_key?(shortname.to_sym)
       end
    end
    return shortname if shortname
    super(attname)
  end

  # Restores from old_params any attributes listed in the
  # untouchable_params_attributes hash, potentially including those
  # defined in unpresetable_params
  def restore_untouchable_attributes(old_params, options = {}) #:nodoc:
    cur_params    = self.params || {}
    untouchables  = self.wrapper_untouchable_params_attributes
    unpresetables = options[:include_unpresetable] ? self.wrapper_unpresetable_params_attributes : {}
    att_list = untouchables.keys + unpresetables.keys
    att_list.each do |untouch|
      cur_params[untouch] = old_params[untouch] if old_params.has_key?(untouch)
    end
    self.params = cur_params
    true
  end

end

# NOTE: Now handled by adding a path to config/application.rb

## Patch: pre-load all model files for the subclasses
#Dir.chdir(CBRAIN::TasksPlugins_Dir) do
#  Dir.glob("*.rb").each do |model|
#    next if model == "cbrain_task_class_loader.rb"
#    model.sub!(/.rb$/,"")
#    unless CbrainTask.const_defined? model.classify
#      puts_blue "Loading CbrainTask subclass #{model.classify} from #{model}.rb ..."
#      require_dependency "#{CBRAIN::TasksPlugins_Dir}/#{model}.rb"
#    end
#  end
#end

