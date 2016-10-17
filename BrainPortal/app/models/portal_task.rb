
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

# This subclass of CbrainTask provides the methods and developer API
# for deploying CbrainTasks on the BrainPortal side.
class PortalTask < CbrainTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  validate              :task_is_proper_subclass

  # This associate one of the keywords we use in the interface
  # to a task status that 'implements' the operation (basically,
  # simply setting the task's status to the value modifies the
  # task's state). This is used in the tasks controller
  # for issuing 'alter_tasks' remote commands.
  #
  # Really, this should not be in the model, but in the controller somewhere.
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
    "duplicate"           => "Duplicated",
    "archive"             => "ArchiveWorkdir",
    "archive_file"        => "ArchiveWorkdirAsFile",
    "unarchive"           => "UnarchiveWorkdir",
    "zap_wd"              => "RemoveWorkdir",
  }

  # In order to optimize the set of state transitions
  # allowed in the tasks, this hash list when we can
  # attempt to change the tasks states. This is
  # used by the tasks controller so as not to send
  # messages to Bourreaux to do stuff on tasks that
  # are not ready for it anyway.
  #
  # Really, this should not be in the model, but in the controller somewhere.
  AllowedOperations = { # 'Destroy' is handled differently and separately

    #===============================================================================
    # Active states
    #===============================================================================

    # Current                          => List of states we can change to
    #--------------------------------  ---------------------------------------------
    "New"                              => [               "Terminated"              ],
    "Queued"                           => [ "Duplicated", "Terminated", "On Hold"   ],
    "On Hold"                          => [ "Duplicated", "Terminated", "Queued"    ],
    "On CPU"                           => [ "Duplicated", "Terminated", "Suspended" ],
    "Suspended"                        => [ "Duplicated", "Terminated", "On CPU"    ],

    #===============================================================================
    # Passive states
    #===============================================================================

    # Current                          => List of states we can change to
    #--------------------------------  ---------------------------------------------
    "Failed To Setup"                  => [ "Duplicated", "Recover", "ArchiveWorkdir", "ArchiveWorkdirAsFile", "UnarchiveWorkdir", "RemoveWorkdir" ],
    "Failed On Cluster"                => [ "Duplicated", "Recover", "ArchiveWorkdir", "ArchiveWorkdirAsFile", "UnarchiveWorkdir", "RemoveWorkdir" ],
    "Failed To PostProcess"            => [ "Duplicated", "Recover", "ArchiveWorkdir", "ArchiveWorkdirAsFile", "UnarchiveWorkdir", "RemoveWorkdir" ],
    "Failed Setup Prerequisites"       => [ "Duplicated", "Recover", "ArchiveWorkdir", "ArchiveWorkdirAsFile", "UnarchiveWorkdir", "RemoveWorkdir" ],
    "Failed PostProcess Prerequisites" => [ "Duplicated", "Recover", "ArchiveWorkdir", "ArchiveWorkdirAsFile", "UnarchiveWorkdir", "RemoveWorkdir" ],
    "Terminated"                       => [ "Duplicated", "Restart Setup", "ArchiveWorkdir", "ArchiveWorkdirAsFile", "UnarchiveWorkdir", "RemoveWorkdir" ],
    "Completed"                        => [ "Duplicated", "Restart Setup", "Restart Cluster", "Restart PostProcess", "ArchiveWorkdir", "ArchiveWorkdirAsFile", "UnarchiveWorkdir", "RemoveWorkdir" ],
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

    #===============================================================================
    # Special states used by serializers and parallelizers
    #===============================================================================

    "Standby"                          => [],
    "Configured"                       => [ "Terminated" ],
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
    self.addlog("#{baserev.basename} rev. #{baserev.short_commit}", :caller_level => 2)
    self.addlog("#{subrev.basename} rev. #{subrev.short_commit}",   :caller_level => 2)
  end

  # Backwards compatibility auto adaptation:
  # if a task's code is extended to include new parameters,
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
  # on a button matching refresh_form_regex (/refresh/ by default)
  # when creating a new task or editing an existing one. It
  # doesn't have to do anything, but usually it's
  # convenient when we want to dynamicallty adjust
  # some of the form elements.
  def refresh_form
    ""
  end

  # This method is called to check if a task form submission
  # corresponds to a refresh action. If the button the user clicked
  # matches this, refresh_form is called.
  # Defaults to /refresh/
  def refresh_form_regex
    /refresh/i
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

  #######################################################
  # Task View API
  #######################################################

  # This method is used to display a progress bar in the task view
  # interface. It returns a hash with the following content:
  #   * :color: a string containing the color to use in the progress bar.
  #   * :progress: an int between 0 and 100 that represents the progression percentage.
  #   * :message: a string that contains an information message.
  #   * :show_percentage: a boolean that indicates if the percentage has to be shown.
  # Examples of returned hashes:
  #     {
  #      :color=>"blue",
  #      :progress => 27,
  #      :message => "Everything looks good",
  #      :show_percentage => true
  #     }
  #     {
  #      :color => "rgb(12,44,255)",
  #      :progress => 42,
  #      :message => "Oh no your data is corrupted",
  #      :show_percentage => false
  #     }
  #
  # This is a default implementation where the bar progresses based on
  # the task status. Tasks may override it to show some task-specific
  # progression. It is recommended to keep the following color
  # convention: red is for failed tasks, blue for active ones, green
  # for completed ones.
  def progress_info
    progress=15
    color="blue"
    if CbrainTask::RUNNING_STATUS.include?(self.status)
      progress=15*(1+CbrainTask::RUNNING_STATUS.index(self.status))
    end
    if CbrainTask::COMPLETED_STATUS.include?(self.status)
      color="green"
      progress=100
    end
    if CbrainTask::FAILED_STATUS.include?(self.status)
      color="red"
      progress=100
    end
    return {:color => color, :progress => progress, :message => nil, :show_percentage => false }
  end

  # Returns true if progress bar has to be shown. Task must override this method
  # when the progress bar has to be shown.
  def show_progress_bar?
    false
  end

  ######################################################
  # Task properties directives
  ######################################################

  # Create a property directive named +name+ for property method +method+
  # (property methods are methods expected to return property hashes, such
  # as +untouchable_params_attributes+ and +unpresetable_params_attributes+).
  # If +instance_method+ is given, an instance method is created for the
  # property instead of a class method.
  #
  #   class SomeTask < PortalTask
  #     property_directive.(:task_properties, :properties)
  #     # ...
  #     task_properties :a, :b, :c
  #   end
  # is equivalent to
  #   class SomeTask < PortalTask
  #     def self.properties
  #       { :a => true, :b => true, :c => true }
  #     end
  #   end
  property_directive = lambda do |name, method, instance_method: false|
    define_singleton_method(name) do |*args|
      props = args.last.is_a?(Hash) ? args.pop : {}
      props = props.reverse_merge(args.map { |p| [p, true] }.to_h)

      if instance_method
        define_method(method) { props }
      else
        define_singleton_method(method) { props }
      end
    end
  end

  # Directive versions of +self.properties+, +untouchable_params_attributes+ and
  # +unpresetable_params_attributes+. See +property_directive+ for more
  # information on how they are used.
  property_directive.(:task_properties,     :properties)
  property_directive.(:untouchable_params,  :untouchable_params_attributes,  instance_method: true)
  property_directive.(:unpresetable_params, :unpresetable_params_attributes, instance_method: true)

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
      break unless stringpath =~ /\A(\[?([\w\.\-]+)\]?)/
      brackets = Regexp.last_match[1]   # "[abcdef]"
      key      = Regexp.last_match[2]   # "abcdef"
      stringpath = stringpath[brackets.size .. -1]
      if foundvalue.is_a?(Hash)
        foundvalue = foundvalue[key.to_sym] || foundvalue[key]
      elsif foundvalue.is_a?(Array) && key =~ /\A\d+\z/
        foundvalue = foundvalue[key.to_i]
      else
        cb_error "Can't access params structure for '#{paramspath}' (stopped at '#{key}' with current structure a '#{foundvalue.class}'."
      end
      break if foundvalue.nil?
    end
    cb_error "Can't find intermediate params structure for '#{paramspath}' (stopped at '#{key}' for '#{foundvalue.inspect}')" if stringpath != "" && stringpath != "[]"
    foundvalue
  end

  # Wrapper around the ActiveModel::Errors class.
  # This class answers to the same methods as the errors
  # object but its 'attributes' are actually paramspaths.
  #
  # See the Rails classes ActiveModel::Validations and
  # ActiveModel::Errors for more information.
  #
  # One major difference between the standard Errors model
  # and this implementation is that the params attribute
  # names are stored as keys 'encoded' with a prefix.
  # E.g. the parameter :xyz is stored with key
  # :cbrain_task_BRA_params_KET__BRA_xyz_KET_ and "hello[goodbye]" with
  # key :cbrain_task_BRA_params_KET__BRA_hello_KET__BRA_goodbye_KET_. This
  # however is transparent to the user of the class.
  class ParamsErrors

    include Enumerable

    attr_writer :real_errors, :base

    def [](paramspath) #:nodoc:
      @real_errors[path2key(paramspath)]
    end

    def []=(paramspath,*args) #:nodoc:
      @real_errors.add(path2key(paramspath),*args)
    end

    def add(paramspath,*args) #:nodoc:
      @real_errors.add(path2key(paramspath),*args)
    end

    def add_on_blank(paramspaths,*args) #:nodoc:
      Array(paramspaths).map do |paramspath|
        value = @base.params_path_value(paramspath.to_s)
        add(paramspath, "is blank") if value.blank?
      end.compact
    end

    def add_on_empty(paramspaths,*args) #:nodoc:
      Array(paramspaths).map do |paramspath|
        value = @base.params_path_value(paramspath.to_s)
        is_empty = value.respond_to?(:empty?) ? value.empty? : false
        add(paramspath, "is empty") if value.nil? || is_empty
      end.compact
    end

    def as_json(*args) #:nodoc:
      to_hash.as_json(*args)
    end

    def blank? #:nodoc:
      count.zero?
    end

    def clear #:nodoc:
      keys.each { |k| delete(k) }
    end

    def count #:nodoc:
      inject(0) { |c| c += 1 }
    end

    def delete(paramspath) #:nodoc:
      @real_errors.delete(path2key(paramspath))
    end

    def each(&block) #:nodoc:
      @real_errors.each do |attr, msg|
        next unless attr.to_s =~ /^cbrain_task_BRA_params_KET_/ # see path2key below
        yield key2path(attr), msg
      end
    end

    def empty? #:nodoc:
      count == 0
    end

    def full_message(paramspath, message) #:nodoc:
      human = PortalTask.human_attribute_name(paramspath)
      "#{human} #{message}"
    end

    def full_messages #:nodoc:
      map { |paramspath, msg| full_message(paramspath, msg) }
    end

    def full_messages_for(paramspath) #:nodoc:
      self[paramspath].map { |msg| full_message(paramspath, msg) }
    end

    def get(paramspath) #:nodoc:
      # for some reason the get() and set() method REALLY want a symbol
      @real_errors.get(path2key(paramspath))
    end

    def include?(paramspath) #:nodoc:
      @real_errors.include?(path2key(paramspath))
    end

    def keys #:nodoc:
      map { |key, _| key }.uniq
    end

    def set(paramspath, value) #:nodoc:
      # for some reason the get() and set() method REALLY want a symbol
      @real_errors.set(path2key(paramspath), Array(value))
    end

    def to_hash(full_messages = false) #:nodoc:
      inject({}) do |hash, pair|
        paramspath, msg = *pair
        hash[paramspath] ||= []
        hash[paramspath] << (full_messages ? full_message(paramspath, msg) : msg)
        hash
      end
    end

    def to_xml(options={}) #:nodoc:
      to_a.to_xml options.reverse_merge(:root => "errors", :skip_types => true)
    end

    def values #:nodoc:
      keys.map { |paramspath| self[paramspath] }
    end

    alias :key?      :include?
    alias :has_key?  :include?
    alias :added?    :include?
    alias :to_a      :full_messages
    alias :size      :count

    private

    # Will transform an arbitrary paramspath, such as "abc[def]"
    # into a sort of key which likely will not interfere with
    # the real attributes of the model, e.g.
    #
    #   :cbrain_task_BRA_params_KET__BRA_abc_KET__BRA_def_KET_
    #
    # Right now this method just calls the String method to_la_id().
    # The key returned is a symbol.
    def path2key(paramspath) #:nodoc:
      paramspath.to_la_id.to_sym
    end

    # Does the reverse of path2key(); the result is a string.
    #
    # From :cbrain_task_BRA_params_KET__BRA_abc_KET__BRA_def_KET_
    # will return "abc[def]".
    def key2path(key) #:nodoc:
      key.to_s.from_la_id
    end

  end

  # Returns the equivalent of the 'errors' object for the
  # task, but where the attributes are in fact paramspath
  # values for the task's params[] hash. This works much like
  # the standard ActiveModel::Errors class. This is used for
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
    @params_errors_cache.base        = self
    @params_errors_cache
  end

  # This method returns a 'pretty' name for a params attributes.
  # This implementation will try to look up a hash table returned
  # by the class method pretty_params_names() first, so an
  # easy way to provide beautiful names for your parameters
  # is to make pretty_params_names() return such a hash.
  def self.human_attribute_name(attname,options={})
    sattname   = attname.to_s.from_la_id # string version of attname, which is usually a symbol now
    prettyhash = self.pretty_params_names || {}
    # We try to guess many ways that the task programmer could have
    # stored for the keys of his 'pretty' names in the hash.
    if prettyhash.size > 0
       extended = prettyhash.dup.with_indifferent_access
       prettyhash.each do |att,name| # extend it with to_la_id automatically...
         next unless att.is_a?(String) && att.include?('[')
         id_att = att.to_la_id
         next if extended.has_key?(id_att)
         extended[id_att] = name
       end
       return extended[sattname]        if extended.has_key?(sattname)
    end
    super(sattname,options)
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



  ##################################################################
  # Bourreau-side Connection Methods
  ##################################################################

  # Contacts the Bourreau side and request a copy of the tasks's
  # STDOUT, STDERR and job script.
  def capture_job_out_err(run_number=nil,stdout_lim=2000,stderr_lim=2000)
    cb_error "Cannot get task's stdout and stderr: this task is archived." if self.workdir_archived?
    bourreau             = self.bourreau
    control              = bourreau.send_command_get_task_outputs(self.id,run_number,stdout_lim,stderr_lim)
    self.cluster_stdout = control.cluster_stdout
    self.cluster_stderr = control.cluster_stderr
    self.script_text    = control.script_text
    true
  end



  ##################################################################
  # Methods To Fetch View Files
  ##################################################################

  # Returns the directory where some public assets (files) for the current task
  # can be found, as served from the webserver. For a task such as UnixWc,
  # it would map to this relative path:
  #
  #   "/cbrain_plugins/cbrain_tasks/unix_wc"
  #
  # This relative path, as seen from the "public" directory of the Rails app,
  # is a symbolic link to the "views/public" subdirectory where the task plugin
  # was installed.
  #
  # When given an argument 'public_file', the path returned will be extended
  # to point to a sub file of that directory. E.g. with "abc/def.csv" :
  #
  #   "/cbrain_plugins/cbrain_tasks/unix_wc/abc/def.csv"
  #
  # Returns nil if no file exists that match the argument 'public_file'.
  # Otherwise, returns a Pathname object.
  def self.public_path(public_file=nil)
    base = Pathname.new("/cbrain_plugins/cbrain_tasks") + self.to_s.demodulize.underscore
    return base if public_file.blank?
    public_file = Pathname.new(public_file.to_s).cleanpath
    raise "Public file path outside of task plugin." if public_file.absolute? || public_file.to_s =~ /\A\.\./
    base = base + public_file
    return nil unless File.exists?((Rails.root + "public").to_s + base.to_s)
    base
  end

  # See the class method of the same name.
  def public_path(public_file=nil)
    self.class.public_path(public_file)
  end


  ##################################################################
  # Lifecycle hooks
  ##################################################################

  private

  # Returns true only if
  def task_is_proper_subclass #:nodoc:
    return true if PortalTask.descendants.include? self.class
    self.errors.add(:base, "is not a proper subclass of PortalTask.")
    false
  end

end

# Patch: pre-load all model files for the subclasses
[ CBRAIN::TasksPlugins_Dir, CBRAIN::TaskDescriptorsPlugins_Dir ].each do |dir|
  Dir.chdir(dir) do
    Dir.glob("*.rb").each do |model|
      next if [
        'cbrain_task_class_loader.rb',
        'cbrain_task_descriptor_loader.rb'
      ].include?(model)

      model.sub!(/.rb\z/, '')
      require_dependency "#{dir}/#{model}.rb" unless
        [ model.classify, model.camelize ].any? { |m| CbrainTask.const_defined?(m) rescue nil }
    end
  end
end
