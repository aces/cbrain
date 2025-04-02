
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

# This model represents a tool's configuration prefix.
# Unlike other models, the set of ToolConfigs is not
# arbitrary. They fit in three categories:
#
# * A single tool config object represents the initialization
#   needed by a particular tool on all bourreaux; it
#   has a tool_id and no bourreau_id
# * A single tool config object represents the initialization
#   needed by a particular bourreau for all tools; it
#   has a bourreau_id and no tool_id
# * A set of 'versioning' tool config objects have both
#   a tool_id and a bourreau_id; they represent all
#   available versions of a tool on a particular bourreau.
class ToolConfig < ApplicationRecord

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  serialize       :env_array

  belongs_to      :bourreau, :optional => true     # can be nil; it means it applies to all bourreaux
  belongs_to      :tool, :optional => true         # can be nil; it means it applies to all tools
  has_many        :cbrain_tasks
  belongs_to      :group
  belongs_to      :container_image, :class_name => 'Userfile', :foreign_key => :container_image_userfile_id, :optional => true

  # Resource usage is kept forever even if tool config is destroyed.
  has_many        :resource_usage

  # first character must be alphanum, and can contain only alphanums, '.', '-', '_', ':' and '@'
  # must be unique per pair [tool, server]
  validates       :version_name,
                  :presence   => true,
                  :format     => { :with    => /\A\w[\w\.\-\:\@]*\z/,
                                   :message => "must begin with alphanum, and can contain only alphanums, '.', '-', '_', ':' and '@'" },
                  :uniqueness => { :scope   => [ :tool_id, :bourreau_id ],
                                   :message => "must be unique per pair [tool, server]" },
                  :if         => :applies_to_bourreau_and_tool?

  validate        :validate_container_rules
  validate        :validate_overlays_specs
  validate        :prevent_version_name_change_for_boutiques_tool

  scope           :global_for_tools     , -> { where( { :bourreau_id => nil } ) }
  scope           :global_for_bourreaux , -> { where( { :tool_id => nil } ) }
  scope           :specific_versions    , -> { where( "bourreau_id is not null and tool_id is not null" ) }

  api_attr_visible :version_name, :description, :tool_id, :bourreau_id, :group_id, :ncpus

  # given array of pairs variable/value builds export script, a prefix is added to variables options
  def vars_to_export_script(varprefix="")
    env = self.env_array || []
    commands = ""
    env.each do |name_val|
      name = name_val[0]
      val  = name_val[1]
      name.strip!
      #val.gsub!(/'/,"'\''")
      commands += "export #{varprefix}#{name}=\"#{val}\"\n"
    end
    commands += "\n" if env.size > 0
    commands
  end

  # To make it somewhat compatible with the ResourceAccess module,
  # here's this model's own method for checking if it's visible to a user.
  def can_be_accessed_by?(user)
    return false unless self.group.can_be_accessed_by?(user)
    return false unless self.bourreau_and_tool_can_be_accessed_by?(user)
    true
  end

  # See ResourceAccess.
  def self.find_all_accessible_by_user(user) #:nodoc:
    if user.has_role?(:admin_user)
      ToolConfig.specific_versions
    else
      gids = user.group_ids
      bids = Bourreau.find_all_accessible_by_user(user).ids
      tids = Tool.find_all_accessible_by_user(user).ids
      ToolConfig.specific_versions.where(:group_id => gids, :bourreau_id => bids, :tool_id => tids)
    end
  end

  # Returns a AR relation for all ToolConfigs
  # that are on +bourreau+ and have the
  # same tool, version_name and group as the receiver.
  def all_other_compatible_on_bourreau(bourreau=self.bourreau)
    other_tcs = self.class.where(
      :bourreau_id  => bourreau.id,
      :tool_id      => self.tool_id,
      :version_name => self.version_name,
      :group_id     => self.group_id,
    )
    other_tcs
  end

  # Returns the latest compatible TC on +bourreau+ (from the list returned
  # by all_other_compatible_on_bourreau) that +user+ has access to.
  def find_latest_compatible_for_user_on_bourreau!(user,bourreau)
    all_accessible_ids = self.class.find_all_accessible_by_user(user).pluck(:id)
    found = self.all_other_compatible_on_bourreau(bourreau)
      .where(:id => all_accessible_ids)
      .order("updated_at desc")
      .first
    cb_error "Cannot find compatible ToolConfig on '#{bourreau.name}'" if ! found
    found
  end

  # Returns true if both the bourreau and the tool associated
  # with the tool_config are defined and can be accessed by the user.
  def bourreau_and_tool_can_be_accessed_by?(user)
    self.bourreau && self.bourreau.can_be_accessed_by?(user) &&
    self.tool     && self.tool.can_be_accessed_by?(user)
  end

  # Returns the verion name or the first line of the description.
  # This is used to represent the 'name' of the version.
  def short_description
    description = self.description || ""
    raise "Internal error: can't parse description!?!" unless description =~ /\A(.+\n?)/ # the . doesn't match \n
    header = Regexp.last_match[1].strip
    header
  end

  # A synonym for version_name.
  def name
    self.version_name rescue "Tool version ##{self.id}"
  end

  # Sets in the current Ruby process all the environment variables
  # defined in the object. If +use_extended+ is true, the
  # set of variables provided by +extended_environement+ will be
  # applied instead.
  def apply_environment(use_extended = false)
    env   = (use_extended ? self.extended_environment : self.env_array) || []
    saved = ENV.to_hash
    env.each do |name,val|
      if val =~ /\$/
#puts_green "THROUGH BASH: #{name} => #{val}" # debug
        newval = `bash -c 'echo \"#{val.strip}\"'`.strip  # this is quite inefficient, but how else to do it?
#puts_green "RESULT:     : #{name} => #{newval}" # debug
      else
#puts_green "DIRECT      : #{name} => #{val}" # debug
        newval = val
      end
      ENV[name.to_s]=newval.to_s
    end
    return yield
  ensure
#(ENV.keys - saved.keys).each { |spurious| ENV.delete(spurious.to_s); puts_red "SPURIOUS: #{spurious}" } # debug
#saved.each { |k,v| puts_cyan "RESTORED: #{ENV[k]=v.to_s}" unless ENV[k] == v } # debug
    (ENV.keys - saved.keys).each { |spurious| ENV.delete(spurious.to_s) }
    saved.each { |k,v| ENV[k]=v.to_s unless ENV[k] == v }
  end

  # Returns the set of environment variables as stored in
  # the object, plus a few artificial ones for CBRAIN usage.
  #
  #  CBRAIN_GLOBAL_TOOL_CONFIG_ID     : set to self.id if self represents a TOOL's global config
  #  CBRAIN_GLOBAL_BOURREAU_CONFIG_ID : set to self.id if self represents a BOURREAU's global config
  #  CBRAIN_TOOL_CONFIG_ID            : set to self.id
  #  CBRAIN_TC_VERSION_NAME           : set to self.version_name
  def extended_environment
    env = (self.env_array || []).dup
    if self.id.present?
      env << [ "CBRAIN_GLOBAL_TOOL_CONFIG_ID",     self.id.to_s ] if self.bourreau_id.blank?
      env << [ "CBRAIN_GLOBAL_BOURREAU_CONFIG_ID", self.id.to_s ] if self.tool_id.blank?
      env << [ "CBRAIN_TOOL_CONFIG_ID",            self.id.to_s ] if ! self.tool_id.blank? && ! self.bourreau_id.blank?
    end
    env   << [ "CBRAIN_TC_VERSION_NAME",       self.version_name] if self.version_name.present?
    env
  end

  # Generates a partial BASH script that initializes environment
  # variables and is followed a the script prologue stored in the
  # object. For singularity prologues, special prefixes are added to
  # variable names to ensure they will be propagated to the container
  # even in presence of --cleanenv parameteres and such
  def to_bash_prologue(singularity=false)
    tool     = self.tool
    bourreau = self.bourreau
    group    = self.group

    script = <<-HEADER

#===================================================
# Configuration: # #{self.id} #{self.version_name}
# Tool:          #{tool     ? tool.name     : "ALL"}
# Bourreau:      #{bourreau ? bourreau.name : "ALL"}
# Group:         #{group    ? group.name    : "everyone"}
#===================================================

    HEADER

    if self.tool_id && self.bourreau_id
      desc = self.description || ""
      script += <<-DESC_HEADER
#---------------------------------------------------
# Description:#{desc.blank? ? " (NONE SUPPLIED)" : ""}
#---------------------------------------------------

      DESC_HEADER
      if ! desc.blank?
        desc.gsub!(/\r\n/,"\n")
        desc.gsub!(/\r/,"\n")
        desc_array = desc.split(/\n/).collect { |line| "# #{line}" }
        script += desc_array.join("\n") + "\n\n"
      end
    end

    env = self.env_array || []
    script += <<-ENV_HEADER
#---------------------------------------------------
# Environment variables:#{env.size == 0 ? " (NONE DEFINED)" : ""}
#---------------------------------------------------

    ENV_HEADER
    script += vars_to_export_script

    if singularity
      script += <<-ENV_HEADER
#---------------------------------------------------
# Ensuring that environment variables are propagated:#{env.size == 0 ? " (NONE DEFINED)" : ""}
#---------------------------------------------------

      ENV_HEADER
      script += vars_to_export_script("SINGULARITYENV_")
      script += vars_to_export_script("APPTAINERENV_")  #  SINGULARITYENV is to be depricated

    end
    script += "\n" if env.size > 0

    prologue = self.script_prologue || ""
    script  += <<-SCRIPT_HEADER

#---------------------------------------------------
# Script Prologue:#{prologue.blank? ? " (NONE SUPPLIED)" : ""}
#---------------------------------------------------

    SCRIPT_HEADER
    prologue.gsub!(/\r\n/,"\n")
    prologue.gsub!(/\r/,"\n")
    prologue += "\n" unless prologue =~ /\n\z/

    script += prologue

    script
  end

  # Generates a partial BASH script that unitializes
  # what the script_prologue did. Unlike for to_bash_prologue,
  # it doesn't undo the settings of the environment variables.
  def to_bash_epilogue
    epilogue = self.script_epilogue || ""
    script = <<-SCRIPT_HEADER
#---------------------------------------------------
# Configuration: # #{self.id} #{self.version_name}
# Script Epilogue:#{epilogue.blank? ? " (NONE SUPPLIED)" : ""}
#---------------------------------------------------

    SCRIPT_HEADER
    epilogue.gsub!(/\r\n/,"\n")
    epilogue.gsub!(/\r/,"\n")
    epilogue += "\n" unless epilogue =~ /\n\z/

    script += epilogue

    script
  end

  # Returns true if the object has no environment variables
  # and its script is blank or only contains blank lines or
  # comments.
  def is_trivial?
    return false if self.extra_qsub_args.present?
    return false if self.containerhub_image_name.present?
    return false if self.container_image_userfile_id.present?
    return false if self.container_engine.present?
    return false if self.cloud_disk_image.present?
    return false if self.cloud_vm_user.present?
    return false if self.cloud_ssh_key_pair.present?
    return false if self.cloud_instance_type.present?
    return false if self.cloud_job_slots.present?
    return false if self.cloud_vm_boot_timeout.present?
    return false if self.cloud_vm_ssh_tunnel_port.present?
    return false if (self.env_array || []).any?(&:present?)
    text = self.script_prologue.to_s + "\n" + self.script_epilogue.to_s
    return true if text.blank?
    text_array = text.split(/\n/).reject { |line| line =~ /\A\s*#|\A\s*\z/ }
    return true if text_array.size == 0
    false
  end

  # Returns true if it's a tool config for bourreau only
  def applies_to_bourreau_only?
    self.bourreau_id.present? && !self.tool_id.present?
  end

  # Returns true if it's a tool config for tool only
  def applies_to_tool_only?
    !self.bourreau_id.present? && self.tool_id.present?
  end

  # Returns true if it's a tool config for bourreau and tool
  def applies_to_bourreau_and_tool?
    self.bourreau_id.present? && self.tool_id.present?
  end

  # These methods call compare_versions defined
  # in cbrain_task, defaulting to this class' compare_versions
  # if cbrain_task doesn't have one.
  # Return true if version_name of the current tool_config
  # is greater than version or false in other case
  def is_at_least_version(version)
     if self.cbrain_task_class.respond_to? :compare_tool_config_versions
       self.cbrain_task_class.compare_tool_config_versions(self.version_name,version) >= 0
     else
       self.class.compare_versions(self.version_name,version) >= 0
     end
  end

  # true if singularity image is defined
  def use_singularity?
    return self.container_engine == "Singularity" &&
        ( self.containerhub_image_name.present? ||
            self.container_image_userfile_id.present? )
  end

  # This method calls any custom compare_versions() method defined
  # in the CbrainTask subclass for the tool of the current tool_config.
  # Returns true if the version_name of the current tool_config
  # is 'the same as' +version+ (as far as compare_versions() thinks).
  def is_version(version)
     if self.cbrain_task_class.respond_to? :compare_tool_config_versions
       self.cbrain_task_class.compare_tool_config_versions(self.version_name,version) == 0
     else
       self.class.compare_versions(self.version_name,version) == 0
     end
  end

  # Compare two tool versions in X.X.X.X format
  # Return -1 if v1 <  v2, for example if v1 = "1.0.2" and v2 = "1.1"
  # Return  0 if v1 == v2, for example if v1 = "2.0.4" and v2 = "2.0.4.0"
  # Return  1 if v1 >  v2, for example if v1 = "0.3"   and v2 = "0.2.4"
  def self.compare_versions(v1, v2)
     v1 = /\d+(\.\d+)*/.match(v1).to_s.split('.').map(&:to_i)
     v2 = /\d+(\.\d+)*/.match(v2).to_s.split('.').map(&:to_i)
     raise ArgumentError, "Could not extract version" if v1.blank? || v2.blank?

     while (v1.size < v2.size) do v1.push(0) end
     while (v2.size < v1.size) do v2.push(0) end

     0.upto(v1.size - 1) { |i| return v1[i] <=> v2[i] unless v1[i] == v2[i] }
     return 0
  end

  # Return the Ruby class associated with the tool associated with this tool_config.
  def cbrain_task_class
    self.tool.cbrain_task_class
  end

  # Returns a hash of full paths to the Singularity overlay files that
  # need to be mounted along with explanation of their origin.
  # Some of paths might
  # be patterns and will need to be resolved at run time. The dsl is
  #      # A file located on the cluster
  #        file:/path/to/file.squashfs
  #      # All overlays configured for DP 1234
  #         dp:1234
  #      # CBRAIN db registered file
  #         userfile:1234
  #      # A ext3 capture filesystem, will NOT be returned here as an overlay
  #         ext3capture:basename=12G
  def singularity_overlays_full_paths
    specs = parsed_overlay_specs
    specs.map do |knd, id_or_name|

      case knd
      when 'dp'
        dp = DataProvider.where_id_or_name(id_or_name).first
        cb_error "Can't find DataProvider #{id_or_name} for fetching overlays" if ! dp
        dp_ovs = dp.singularity_overlays_full_paths rescue nil
        cb_error "DataProvider #{id_or_name} does not have any overlays configured." if dp_ovs.blank?
        dp_ovs.map do |dp_path|
          { dp_path => "Data Provider" }
        end
      when 'file'
        cb_error "Provide absolute path for overlay file '#{id_or_name}'." if (Pathname.new id_or_name).relative?
        { id_or_name => "local file" }  # for local file, it is full file name (no ids)
      when 'userfile'
        # db registered file, note admin can access all files
        userfile = SingleFile.where(:id => id_or_name).last
        cb_error "Userfile with id '#{id_or_name}' for overlay fetching not found." if ! userfile
        userfile.sync_to_cache() rescue cb_error "Userfile with id '#{id_or_name}' for fetching overlay failed to synchronize."
        { userfile.cache_full_path() =>  "registered userfile" }
      when 'ext3capture'
        []  # handled separately
      else
        cb_error "Invalid '#{knd}:#{id_or_name}' overlay."
      end
    end.flatten.reduce(&:merge) || []
  end

  # Returns an array of the data providers that are
  # specified in the attribute singularity_overlays_specs,
  # ignoring all other overlay specs for normal files.
  def data_providers_with_overlays
    return @_data_providers_with_overlays_ if @_data_providers_with_overlays_
    specs = parsed_overlay_specs
    return [] if specs.empty?
    @_data_providers_with_overlays_ = specs.map do |kind, id_or_name|
      DataProvider.where_id_or_name(id_or_name).first if kind == 'dp'
    end.compact
  end

  # Returns pairs [ [ basename, size], ...] as in [ [ 'work', '28g' ]
  def ext3capture_basenames
    specs = parsed_overlay_specs
    return [] if specs.empty?
    specs
      .map { |pair| pair[1] if pair[0] == 'ext3capture' }
      .compact
      .map { |basename_and_size| basename_and_size.split("=") }
  end

  #################################################################
  # Validation methods
  #################################################################

  # Validate some rules for container_engine, container_image_userfile_id, containerhub_image_name
  def validate_container_rules #:nodoc:
    # Should only have one container_engine of particular type
    available_engine = ["Singularity","Docker"]
    if self.container_engine.present? && available_engine.exclude?(self.container_engine)
      errors[:container_engine] = "is not valid"
    end
    # Should only have a containerhub_image_name or a container_image_userfile_id
    if self.containerhub_image_name.present? && self.container_image_userfile_id.present?
      errors[:containerhub_image_name]     = "cannot be set when a container image Userfile ID is set"
      errors[:container_image_userfile_id] = "cannot be set when a container hub name is set"
    end
    # A tool_config with a containerhub_image_name or a container_image_userfile_id should have a container_engine
    if (self.containerhub_image_name.present? || self.container_image_userfile_id.present?) && self.container_engine.blank?
      errors[:container_engine] = "should be set when a container image name or a container userfile ID is set"
    end
    # A tool_config with a container_engine should have a containerhub_image_name or a container_image_userfile_id
    if self.container_engine.present? && ( self.containerhub_image_name.blank? && self.container_image_userfile_id.blank? )
      errors[:container_engine] = "a container hub image name or a container image userfile ID should be set when the container engine is set"
    end

    if self.container_engine.present? && self.container_engine == "Singularity"
      if self.container_index_location.present? && self.container_index_location !~ /\A[a-z0-9]+\:\/\/\z/i
        errors[:container_index_location] = "is invalid for container engine Singularity. Should end in '://'."
      end
    elsif self.container_engine.present? && self.container_engine == "Docker"
      if self.container_index_location.present? && self.container_index_location !~ /\A[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,6}\z/i
        errors[:container_index_location] = "is invalid for container engine Docker. Should be a valid hostname."
      end
    end
    return errors.empty?
  end

  # breaks down overlay spec onto a list of overlays
  def parsed_overlay_specs
    specs = self.singularity_overlays_specs
    return [] if specs.blank?
    lines = specs.split(/^#.*|\s+#.*|\n/) # split on lines and drop comments
    lines.map(&:presence).compact.map do |spec|
      spec.strip.split(':', 2)
    end
  end

  # Verifies that the admin has entered a set of
  # overlay specifications properly. One or several of:
  #
  #    file:/full/path/to/something.squashfs
  #    file:/full/path/to/pattern*/data?.squashfs
  #    userfile:333
  #    dp:123
  #    dp:dp_name
  #    ext3capture:basename=SIZE
  #    ext3capture:work=30G
  #    ext3capture:tool_1.1.2=15M
  #
  def validate_overlays_specs #:nodoc:
    specs = parsed_overlay_specs

    # Iterate over each spec and validate them
    specs.each do |kind, id_or_name|

      case kind # different validations rules for file, userfile and dp specs
      when 'file' # full path specification for a local file, e.g. "file:/myfiles/c.sqs"
        if id_or_name !~ /^\/\S+\.(sqs|sqfs|squashfs)$/
          self.errors.add(:singularity_overlays_specs,
            " contains invalid #{kind} named '#{id_or_name}'. It should be a full path that ends in .squashfs, .sqs or .sqfs")
        end

      when 'userfile' # db-registered file spec, e.g. "userfile:42"
        if id_or_name !~ /\A\d+\z/
          self.errors.add(:singularity_overlays_specs,
            %{" contains invalid userfile id '#{id_or_name}'. The userfile id should be an integer number."}
          )
        else
          userfile = SingleFile.where(:id => id_or_name).first
        end
        if ! userfile
          self.errors.add(:singularity_overlays_specs,
            %{" contains invalid userfile id '#{id_or_name}'. The file with id '#{id_or_name}' is not found."}
          )
        elsif userfile.name.to_s !~ /\.(sqs|sqfs|squashfs)$/
          self.errors.add(:singularity_overlays_specs,
          " contains invalid userfile with id '#{id_or_name}' and name '#{userfile.name}'. File name should end in .squashfs, .sqs or .sqfs")
          # todo maybe or/and check file type?
        end

      when 'dp' # DataProvider specs: "dp:name" or "dp:ID"
        dp = DataProvider.where_id_or_name(id_or_name).first
        if !dp
          self.errors.add(:singularity_overlays_specs, "contains invalid DP '#{id_or_name}' (no such DP)")
        elsif ! dp.is_a?(SingSquashfsDataProvider)
          self.errors.add(:singularity_overlays_specs, "DataProvider '#{id_or_name}' is not a SingSquashfsDataProvider")
        end

      when 'ext3capture' # ext3 filesystem as a basename with an initial size
        # The basename is limited to letters, digits, numbers and dashes; the =SIZE suffix must end with G or M
        if id_or_name !~ /\A\w[\w\.-]+=([1-9]\d*)[mg]\z/i
          self.errors.add(:singularity_overlays_specs, "contains invalid ext3capture specification (must be like ext3capture:basename=1g or 2m etc)")
        end

      else
        # Other errors
        self.errors.add(:singularity_overlays_specs, "contains invalid specification '#{kind}:#{id_or_name}'")
      end
    end

    errors.empty?
  end

  # Since the version_name of the tool config is used as
  # a lookup in the ToolConfig class to find the associated
  # Boutiques descriptor, we can't change it. We'd
  # need a way to adjust the lookup table too, and
  # also the content of the files on disk. Ideally,
  # the JSON file should be linked by the IDs instead...
  def prevent_version_name_change_for_boutiques_tool #:nodoc:
    return if     self.new_record?
    return unless self.version_name_change
    return unless self.tool&.cbrain_task_class_name&.to_s&.match(/^BoutiquesTask::/)
    self.errors.add(:version_name, 'cannot be changed because this is a Boutiques tool')
  end

  ##################################################################
  # CARMIN converters
  ##################################################################

  public

  # Returns a CARMIN-compliant structure for their 'Piepline' model.
  # We combine the information of the ToolConfig, and its associated
  # Bourreau and Tool.
  def to_carmin #:nodoc:
    bourreau = self.bourreau
    tool     = self.tool
    {
      :identifier         => self.id,
      :name               => "#{tool.name}@#{bourreau.name}",
      :version            => self.version_name,
      :description        => "#{tool.description}\n#{self.description}".strip,
      :canExecute         => true,
      :parameters         => [ { } ], # PipelineParameter ... TODO
      :properties         => {
        :tool_name    => tool.name,
        :exec_name    => bourreau.name,
        :version_name => self.version_name,
      },
      :errorCodesAndMessages => [], # TODO
    }
  end

  ##################################################################
  # Boutiques Integrator: Descriptor Registration
  ##################################################################

  public

  # This method stores in a class-level hash a BoutiquesDescriptor object
  # associated with the attributes Tool#name and ToolConfig#tool_version .
  # A tool config can then find a descriptor associated with itself using
  # the lookup method registered_boutiques_descriptor().
  def self.register_descriptor(descriptor, tool_name, tool_version) #:nodoc:
    @_descriptors_ ||= {}
    key = [ tool_name, tool_version ] # two strings
    if @_descriptors_[key]
      cb_error "Duplicate registration of a descriptor for Tool=#{tool_name} and Version=#{tool_version}"
    end
    @_descriptors_[key] = descriptor
    tool         = Tool.where(:name => tool_name).first
    tool_id      = tool.try(:id) || -999 # the -999 is just so the lookup below finds nothing
    tool_configs = ToolConfig.where(:tool_id => tool_id, :version_name => tool_version)
    tool_configs # returns the list of tool_configs in the DB that match the tool name and version
  end

  def self.registered_boutiques_descriptor(tool_name, tool_version) #:nodoc:
    @_descriptors_ ||= {}
    key = [ tool_name, tool_version ] # two strings
    @_descriptors_[key] = @_descriptors_[key]&.reload_if_file_timestamp_changed
    @_descriptors_[key]
  end

  def boutiques_descriptor
    path = boutiques_descriptor_path.presence
    return self.class.registered_boutiques_descriptor(self.tool.name, self.version_name) if ! path

    if @_descriptor_
      @_descriptor_       = @_descriptor_.reload_if_file_timestamp_changed
      key                 = [ self.tool.name, self.version_name ] # two strings
      @_descriptors_    ||= {}
      @_descriptors_[key] = @_descriptor_
      return @_descriptor_
    end

    path = Pathname.new(path)
    path = Pathname.new(CBRAIN::BoutiquesDescriptorsPlugins_Dir) + path if path.relative?
    @_descriptor_ = BoutiquesSupport::BoutiquesDescriptor.new_from_file(path)
  end

  def boutiques_descriptor_origin_keyword
    manual     = self.boutiques_descriptor_path.presence
    registered = self.class.registered_boutiques_descriptor(self.tool.name, self.version_name)
    return [ :overriden, manual ]               if registered && manual
    return [ :manual,    manual ]               if manual
    return [ :automatic, registered.from_file ] if registered
    return [ :none,      "" ]
  end

  def self.create_from_descriptor(bourreau, tool, descriptor, record_path=false)

    # Check if there is already a TC
    tc = ToolConfig.where(
      :tool_id      => tool.id,
      :bourreau_id  => bourreau.id,
      :version_name => descriptor.tool_version,
    ).first
    return tc if tc

    container_info   = descriptor.container_image || {}
    container_engine = container_info['type'].presence.try(:capitalize)
    container_engine = "Singularity" if (container_engine == "Docker" &&
                                         !bourreau.docker_present?    &&
                                          bourreau.singularity_present?
                                        )
    container_index  = container_info['index'].presence
    container_index  = 'docker://' if container_index == 'index.docker.io' # old convention
    tc = ToolConfig.create!(
      # Main three keys
      :tool_id         => tool.id,
      :bourreau_id     => bourreau.id,
      :version_name    => descriptor.tool_version,
      # Other attributes
      :group_id        => User.admin.own_group.id,
      :description     => descriptor.description.to_s + "\n\n(Auto-created by Boutiques integrator)",
      :env_array       => [],
      :script_prologue => nil,
      :script_epilogue => nil,
      :ncpus           => 1,
      :inputs_readonly => descriptor.custom['cbrain:readonly-input-files'].present?,
      :boutiques_descriptor_path => (record_path.presence && descriptor.from_file),
      # The following three attributes are for containerization; not sure about values
      :container_engine          => container_engine,
      :container_index_location  => container_index,
      :containerhub_image_name   => container_info['image'].presence,
    )

    tc.addlog("Automatically configured from a Boutiques descriptor")
    tc.addlog("Descriptor path: #{descriptor.from_file}") if descriptor.from_file
    tc
  end

end
