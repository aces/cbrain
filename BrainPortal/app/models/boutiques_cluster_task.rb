
#
# CBRAIN Project
#
# Copyright (C) 2008-2021
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

class BoutiquesClusterTask < ClusterTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Descriptor-based tasks are, by default, easily restartable and recoverable
  include RestartableTask
  include RecoverableTask

  # This method returns the BoutiquesDescriptor
  # directly associated with the ToolConfig for the task
  def boutiques_descriptor
    self.tool_config.boutiques_descriptor
  end

  # This method returns the same descriptor as
  # boutiques_descriptor(), by default, but can be overriden
  # by subclasses to change the behavior of what happens
  # in the setup() method.
  def descriptor_for_setup
    self.boutiques_descriptor
  end

  # This method returns the same descriptor as
  # boutiques_descriptor(), by default, but can be overriden
  # by subclasses to change the behavior of what happens
  # in the cluster_commands() method.
  def descriptor_for_cluster_commands
    desc = self.boutiques_descriptor.dup
    desc.delete "container-image" # CBRAIN handles containerization itself
    desc
  end

  # This method returns the same descriptor as
  # boutiques_descriptor(), by default, but can be overriden
  # by subclasses to change the behavior of what happens
  # in the save_results() method.
  def descriptor_for_save_results
    self.boutiques_descriptor
  end



  ##############################
  # STANDARD PORTAL TASK METHODS
  ##############################

  def self.properties #:nodoc:
    {
      :can_submit_new_tasks => false, # TODO this is a class method, no access to descriptor
    }
  end

  def setup
    descriptor = self.descriptor_for_setup
    self.addlog(descriptor.file_revision_info.format("%f rev. %s %a %d"))

    descriptor.file_inputs.each do |input|
      userfile_id = invoke_params[input.id]
      next if userfile_id.blank? # that happens when it's an optional file
      userfile    = Userfile.find(userfile_id)

      # Most common situation
      if ! input.list || ! userfile.is_a?(CbrainFileList)
        make_available(userfile, userfile.name)
        next
      end

      # In case the input is a list and is assigned a CbrainFileList
      userfile.sync_to_cache
      userfile_list = cbrainfilelist.userfiles_accessible_by_user!(user, nil, nil, file_access_symbol)
      userfile_list.compact.each do |subfile|
        make_available(subfile, subfile.name)
      end
    end

    true
  end

  def cluster_commands
    # Our two main JSON structures for 'bosh'
    descriptor    = self.descriptor_for_cluster_commands
    invoke_struct = self.invoke_params.dup

    # Replace userfile IDs for file basenames in the invoke struct
    descriptor.file_inputs.each do |input|
      userfile_id = invoke_params[input.id]
      next if userfile_id.blank? # that happens when it's an optional file
      userfile    = Userfile.find(userfile_id)

      # Most common situation
      if ! input.list || ! userfile.is_a?(CbrainFileList)
        invoke_struct[input.id] = (input.list ? [ userfile.name ] : userfile.name)
        next
      end

      # In case the input is a list and is assigned a CbrainFileList
      userfile.sync_to_cache
      userfile_list = cbrainfilelist.userfiles_accessible_by_user!(user, nil, nil, file_access_symbol)
      subnames = userfile_list.compact.map(&:name)  # [ 'userfilename1', 'userfilename2' ... ]
      invoke_struct[input.id] = subnames
    end

    # Replace the "0"/"1" strings we use for booleans with true and false
    descriptor.inputs.select { |input| input.type == 'Flag' }.each do |input|
      next if invoke_struct[input.id].blank?
      invoke_struct[input.id] = true  if invoke_struct[input.id] == '1'
      invoke_struct[input.id] = false if invoke_struct[input.id] == '0'
    end

    # Write down the file with the invoke struct
    invoke_json_basename = "invoke.#{self.run_id}.json"
    File.open(invoke_json_basename ,"w") do |fh|
      fh.write JSON.pretty_generate(invoke_struct)
      fh.write "\n"
    end

    # Write down the file with the boutiques descriptor itself
    boutiques_json_basename = "boutiques.#{self.run_id}.json"
    File.open(boutiques_json_basename, "w") do |fh|
      cleaned_desc = descriptor.dup
      cleaned_desc.delete("groups") if cleaned_desc.groups.size == 0 # bosh is picky
      fh.write JSON.pretty_generate(cleaned_desc)
      fh.write "\n"
    end

    if self.boutiques_bosh_exec_mode == :simulate # the default
      simulate_com = <<-SIMULATE
        bosh exec simulate
          -i #{invoke_json_basename.bash_escape}
          #{boutiques_json_basename.bash_escape}
      SIMULATE
      simulate_com.gsub!("\n"," ")
      simulout = IO.popen(simulate_com) { |fh| fh.read }
      simul_status = $? # a Process::Status object
      if ! simul_status.success?
        cb_error "The 'bosh exec simulate' command failed with return code #{simul_status.exitstatus}"
      end
      simulout.sub!(/^Generated.*\n/,"") # header junk from simulate
      commands = <<-COMMANDS
        # Main tool command, generated with bosh exec simulate
        #{simulout.strip}
        echo $? > #{exit_status_filename.bash_escape}
      COMMANDS
    else # exec launch mode
      # The bosh launch command. This is all a single line, but broken up
      # for readability.
      commands = <<-COMMANDS
        # Main tool command, invoked through bosh exec launch
        bosh exec launch                                                          \\
          #{boutiques_json_basename.bash_escape}                                  \\
          #{invoke_json_basename.bash_escape}
          echo $? > #{exit_status_filename.bash_escape}
      COMMANDS
    end
    commands.gsub!(/(\S)  +(\S)/,'\1 \2') # make pretty

    [ commands ]
  end

  def save_results
    descriptor = self.descriptor_for_save_results
    custom     = descriptor.custom || {} # 'custom' is not packaged as an object, just a hash

    if ! custom['cbrain:ignore-exit-status']
      out = File.read(exit_status_filename()) rescue nil
      if out.nil?
        self.addlog "Missing exit status file #{exit_status_filename()}"
        return false
      end
      if out.blank?
        self.addlog "Process did not complete successfully: status file is blank"
        return false
      end
      if out !~ /\A\d+\s*\z/
        cb_error "Exit status file #{exit_status_filename()} has unexpected content"
      end
      status = out.strip.to_i
      if status != 0
        self.addlog "Command failed, exit status #{status}"
        return false
      end
    end

    # Prepare the substitution hash, which maps things like
    # [abcd] to a value to replace, in the output files.
    invoke_json_basename    = "invoke.#{self.run_id}.json"
    substitutions_by_ids    = JSON.parse(File.read(invoke_json_basename)) # id => val
    substitutions_by_tokens = descriptor.inputs.map do |input|
      next nil if input.value_key.blank?
      value = substitutions_by_ids[input.id]
      next nil if value.nil?
      [ input.value_key, value ]
    end.compact.to_h

    all_ok           = true
    cbrain_to_ignore = custom['cbrain:ignore_outputs'] || []
    descriptor.output_files
      .select { |output| ! cbrain_to_ignore.include?(output.id) }
      .each do |output|
      globpath = output.path_template
      to_strip = output.path_template_stripped_extensions || []

      # Apply substitutions
      substitutions_by_tokens.each do |key,val|
        next if val.is_a?(Array) # not supported; what would it mean?
        val = val.to_s
        to_strip.each { |str| val = val.sub(/#{Regexp.quote(str)}\z/,"") }
        globpath = globpath.gsub(key, val)
      end

      paths = Dir.glob(globpath)
      if paths.empty?
        if output.optional
          self.addlog("Skipped optional missing output file '#{globpath}' for output #{output.id}")
          next
        end
        self.addlog("Error: couldn't find any output files matching the pattern '#{globpath}' for output #{output.id}")
        all_ok = false
        next
      end

      paths.each do |path|
        if ! path_is_in_workdir?(path) # this also checks the existence
          self.addlog("Output file is missing or outside of task work directory: #{path}")
          all_ok = false
        end

        # Get name and filetype
        self.addlog("Attempting to save result file #{path}")
        name = File.basename(path)
        userfile_class   = Userfile.suggested_file_type(name)
        userfile_class ||= ( File.directory?(path) ? FileCollection : SingleFile )

        # Add a run ID to the file name, to make sure the file doesn't exist.
        name.sub!( /(\.\w+(\.gz|\.z|\.bz2|\.zip)?)?\z/i ) { |ext| "-#{self.run_id}" + ext }

        # Save the file (possible overwrite if race condition)
        outfile = safe_userfile_find_or_new(userfile_class, :name => name)

        unless outfile.save
          messages = outfile.errors.full_messages.join("; ")
          self.addlog("Failed to save file #{path} as #{name}")
          self.addlog(messages) if messages.present?
          all_ok = false
          next
        end

        # Transfer content to DataProvider
        outfile.cache_copy_from_local_file(path)
        params["_cbrain_output_#{output.id}"] ||= []
        params["_cbrain_output_#{output.id}"]  << outfile.id
        self.addlog("Saved result file #{name}")

        # Add provenance logs
        all_file_input_ids = descriptor.file_inputs.map do |input|
          invoke_params[input.id]
        end.compact.uniq
        parent_userfiles = Userfile.where(:id => all_file_input_ids).to_a
        self.addlog_to_userfiles_these_created_these(parent_userfiles, [outfile]) if parent_userfiles.present?

        # If there is only one input file, we move the output under it
        if parent_userfiles.size == 1
          outfile.move_to_child_of(parent_userfiles[0])
        else
          # If there is exactly one mandatory file input, we use it
          # as the parent even when there are other optional files.
          req_file_inputs = descriptor.required_file_inputs
          if req_file_inputs.size == 1
            parent_id = invoke_params[req_file_inputs[0].id]
            outfile.move_to_child_of(parent_id) if parent_id.present?
          end
        end

      end # each path
    end # each output

    resync_inputs = custom['cbrain:save_back_inputs'] || []
    if all_ok
      resync_inputs.each do |input_id|
        userfile_id = invoke_params[input_id].presence
        next if ! userfile_id
        userfile = Userfile.find(userfile_id)
        self.addlog "Attempting to update input '#{userfile.name}' on DataProvider '#{userfile.data_provider.name}'"
        userfile.cache_is_newer
        userfile.sync_to_provider
        self.addlog_to_userfiles_processed(userfile, "(content modified in place)")
      end
    end

    all_ok
  end

  # Conservative maximal run time estimate for the job.
  # This value should be somewhat larger than the longest
  # expected run without being overly excessive; it will be submitted along
  # with the job to the cluster management system for scheduling purposes.
  def job_walltime_estimate
    descriptor = self.descriptor_for_cluster_commands
    custom     = descriptor.custom || {} # 'custom' is not packaged as an object, just a hash
    if custom['cbrain:walltime-estimate'].present?
      return custom['cbrain:walltime-estimate'].seconds
    end
    if descriptor.suggested_resources.present? &&
       descriptor.suggested_resources['walltime-estimate'].present?
       return descriptor.suggested_resources['walltime-estimate'].seconds
    end
    nil
  end

  # Local utility methods

  # Filename used to hold the exit status of the tool.
  # This file is generated as soon as the task is
  # completed and is checked in +save_results+ to make sure the task succeeded.
  def exit_status_filename
    ".qsub.exit.#{self.name}.#{self.run_id}"
  end

  # Returns either :simulate or :launch .
  #
  # In the mode 'simulate', at the moment of creating
  # the tool's script in cluster_commands(), the
  # output of 'bosh exec simulate' will be substituted in
  # the script to generate the tool's command.
  #
  # In the mode 'launch', an actual 'bosh exec launch' command
  # will be put in the script instead.
  #
  # This value can be obtained from the descriptor
  # in the field "custom"['cbrain:boutiques_bosh_exec_mode']
  #
  # The default implied value is :simulate.
  def boutiques_bosh_exec_mode
    custom = descriptor_for_cluster_commands.custom || {}
    mode   = custom['cbrain:boutiques_bosh_exec_mode'].presence
    if mode.to_s == 'launch'
      :launch
    else
      :simulate
    end
  end



  # MAYBE IN COMMON

  def invoke_params
    self.params[:invoke] ||= {}
  end

  # This determines if the task expects to only read its input files,
  # or modify them, and return respectively :read or :write (the default).
  # The symbol can be passed to methods such as Userfile.find_accessible_by_user().
  # Depending on the value, more or less files are allowed to be processed.
  # When the value is :read, it means we only need file for input and not
  # for output.
  def file_access_symbol
    @_file_access ||= (self.class.properties[:readonly_input_files].present? || self.tool_config.try(:inputs_readonly) ? :read : :write)
  end

end
