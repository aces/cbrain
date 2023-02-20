
#
# CBRAIN Project
#
# Copyright (C) 2008-2023
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

# This module allow to save the stdout and stderr files of a Boutiques task
#
# To use this module, you need to add the following lines in the descriptor:
#   "custom_module_info": {
#     "BoutiquesSaveStdOutStdErr": {
#       "stdout_output_dir": "",
#       "stderr_output_dir": "path/to/dir"
#     }
#   }
#
# In case of a MultilevelSshDataProvider the "path/to/dir" will be use to save the output.
# In case of a no MultilevelSshDataProvider the "path/to/dir" will be ignored.
#
# The value of the key "stdout_output_dir" and "stderr_output_dir" can be set to an empty string,
# in this situation the files will be saved directly in the root folder of the DataProvider.
#
# The output files will be saved as a LogFile with the name: <task.pretty_type>-<task.bname_tid_dashed>.std(out|err)
#
module BoutiquesSaveStdOutStdErr

  # Note: to access the revision info of the module,
  # you need to access the constant directly, the
  # object method revision_info() won't work.
  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # This method overrides the one in BoutiquesClusterTask.
  # Save the stdout and stderr files of the task as output files.
  # The files will be saved as a child of the first input file.
  def save_results
    # Get the folder where to save the log files from the descriptor
    descriptor      = self.descriptor_for_save_results
    module_info = descriptor.custom_module_info('BoutiquesSaveStdOutStdErr')

    # Get parent file to set stderr and stdout as children of first input file
    main_input_id = descriptor.file_inputs.first.id
    file_id       = self.invoke_params[main_input_id]
    parent_file   = Userfile.find(file_id)

    # Save stdout
    science_stdout_basename = science_stdout_basename(self.run_number)
    save_stdout_basename    = (Pathname.new(module_info["stdout_output_dir"]) +
                              "#{self.pretty_type}-#{self.bname_tid_dashed}.stdout").to_s
    stdout_file             = save_log_file(science_stdout_basename, save_stdout_basename, parent_file)
    self.params["_cbrain_output_cbrain_stdout"] = [stdout_file.id] if stdout_file

    # Save stderr
    science_stderr_basename = science_stderr_basename(self.run_number)
    save_stderr_basename    = (Pathname.new(module_info["stderr_output_dir"]) +
                              "#{self.pretty_type}-#{self.bname_tid_dashed}.stderr").to_s
    stderr_file             = save_log_file(science_stderr_basename, save_stderr_basename, parent_file)
    self.params["_cbrain_output_cbrain_stderr"] = [stderr_file.id] if stderr_file

    self.save

    super
  end

  # Add the stdout and stderr files to the descriptor
  # for the show page of the task.
  def descriptor_for_show_params  #:nodoc:
    descriptor = super.dup

    stdout_file = BoutiquesSupport::OutputFile.new({
      "id"   => "cbrain_stdout",
      "name" => "stdout",
      "description" => "Standard output of the tool",
      "optional" => true
    })

    stderr_file = BoutiquesSupport::OutputFile.new({
      "id"   => "cbrain_stderr",
      "name" => "stderr",
      "description" => "Standard error of the tool",
      "optional" => true
    })

    descriptor["output-files"] << stdout_file if !descriptor.output_files.any? { |f| f.id == "cbrain_stdout" }
    descriptor["output-files"] << stderr_file if !descriptor.output_files.any? { |f| f.id == "cbrain_stderr" }

    descriptor
  end

  private

  # If the name for the file contains a relative path such
  # as "a/b/c/hello.txt", it will extract the "a/b/c" and
  # provide it in the browse_path attribute to the Userfile
  # constructor in super().
  def safe_logfile_find_or_new(klass, attlist)
    name = attlist[:name]
    return safe_userfile_find_or_new(klass, attlist) if ! (name.include? "/") # if there is no relative path, just do normal stuff

    # Find all the info we need
    attlist = attlist.dup
    dp_id   = attlist[:data_provider_id] || self.results_data_provider_id
    dp      = DataProvider.find(dp_id)
    pn      = Pathname.new(name)  # "a/b/c/hello.txt"

    # Make adjustements to name and browse_path
    attlist[:name] = pn.basename.to_s  # "hello.txt"
    if dp.has_browse_path_capabilities?
      attlist[:browse_path] = pn.dirname.to_s   # "a/b/c"
      self.addlog "BoutiquesSaveStdErrOut: result DataProvider browse_path for Stderr and Stdout will be '#{pn.dirname}'"
    else
      attlist[:browse_path] = nil # ignore the browse_path
      self.addlog "BoutiquesSaveStdErrOut: result DataProvider doesn't have multi-level capabilities, ignoring forced browse_path for Stderr and Stdout '#{pn.dirname}'."
    end

    # Invoke the standard code
    return safe_userfile_find_or_new(klass, attlist)
  end

  # Save the log with original_file_path to filename as
  # a child of parent_file on the results data provider.
  def save_log_file(original_file_path, filename, parent_file) #:nodoc:
    self.addlog("Saving log file #{filename}")
    file = safe_logfile_find_or_new(LogFile, :name => filename)

    if ! file.save
      self.addlog("Could not save back log file #{filename}")
      return nil
    end

    file.cache_copy_from_local_file(original_file_path)
    file.move_to_child_of(parent_file)
    self.addlog("Saved log file #{filename}")

    file
  end
end

