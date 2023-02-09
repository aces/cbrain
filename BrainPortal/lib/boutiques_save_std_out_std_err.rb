
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

# Module to save stdout and stderr files
module BoutiquesSaveStdOutStdErr

  # Note: to access the revision info of the module,
  # you need to access the constant directly, the
  # object method revision_info() won't work.
  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # This method overrides the one in BoutiquesClusterTask
  def save_results
    # Performs standard processing
    return false unless super

    everything_ok = true

    # Get the folder where to save the log files from the descriptor
    descriptor      = self.descriptor_for_save_results
    save_log_folder = descriptor.custom_module_info('BoutiquesSaveStdOutStdErr')
    self.addlog("BoutiquesSaveStdOutStdErr: save_log_folder is '#{save_log_folder.inspect}'")

    # Save stdout and stderr
    parent_file   = Userfile.find((self.params[:invoke] ||= {})[descriptor.file_inputs.first.id])
    everything_ok = save_log_file(science_stdout_basename(self.run_number), parent_file)
    everything_ok = save_log_file(science_stderr_basename(self.run_number), parent_file)

    everything_ok
  end


  # This method overrides the method in BoutiquesClusterTask.
  # If the name for the file contains a relative path such
  # as "a/b/c/hello.txt", it will extract the "a/b/c" and
  # provide it in the browse_path attribute to the Userfile
  # constructor in super().
  def safe_userfile_find_or_new(klass, attlist)
    name = attlist[:name]
    return super(klass, attlist) if ! (name.include? "/") # if there is no relative path, just do normal stuff

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
    return super(klass, attlist)
  end

  private

  def save_log_file(filename, parent_file)
    save_filename = filename.gsub(/^./, '')

    file = safe_userfile_find_or_new(LogFile,
      :name             => save_filename,
      :data_provider_id => self.results_data_provider_id
    )

    file.cache_copy_from_local_file(filename)
    if file.save
      file.move_to_child_of(parent_file)
      self.addlog("Saved output file #{save_filename}")
    else
      self.addlog("Could not save back result file #{save_filename}")
      return false
    end

    true
  end
end

