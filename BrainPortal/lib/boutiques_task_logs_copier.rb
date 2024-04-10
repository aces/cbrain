
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

# This module implement a special step that is executed BEFORE the standard
# post-processing code of CBRAIN is triggered. A Boutiques descriptor can
# include it in the custom section like this:
#
#   "custom": {
#     "cbrain:integrator_modules": {
#       "BoutiquesTaskLogsCopier": {
#          "stdout":     "local/path/[PARAM1]/ses*/basename[PARAM2]_{taskid}_stdout.log",
#          "stderr":     "local/path/[PARAM1]/ses*/basename[PARAM2]_{taskid}_stderr.log",
#          "runtime":    "blah/blah/runtime.kv",
#          "descriptor": "blah/blah/descriptor.json",
#          "invoke":     "blah/blah/params.json",
#          "jobscript":  "blah/blah/cbrain_script.sh",
#          "cbrain_params": "blah/blah/cbparams.json"
#       }
#     }
#   }
#
# The module's behavior is to copy some CBRAIN-specific files (e.g. the STDOUT and STDERR
# capture files of the task) and install them in some subdirectory that (normally)
# will be saved as an output. It can also copy other useful configuration files,
# as shown in the example above.
#
# The copy code will get triggered before CBRAIN runs its normal post-processing
# code, so before it is aware whether or not the task completed successfully,
# or failed.
#
# Configuration errors in the paths will raise a fatal exception. A missing
# output directory path, however, will only generate a warning within
# the task's processing logs.
#
# The pathnames patterns provided can include standard filesystem glob elements
# and Boutiques value-key parameters. The module will try to make sure that
# only one subdirecty path matches the parent location specified by the path, though
# it will attempt the create the last component of the parent if necessary.
#
# Several examples of what is supported:
#
#   # Direct path:
#   "abc/def/stdout.log"
#
#   # Paths with value-keys taken from Boutiques parameters:
#   "[OUTPUT_DIR]/[INPUT_FILE].stdout"
#   "work/[SUBJECT_ID]/logs/stdout_[SUBJECT_ID].log"
#
#   # Path with a value-key AND a glob to find a subdirectory ses-N :
#   "work/[SUBJECT_ID]/ses-*/logs/stdout_[SUBJECT_ID].log"
#
# When tring to find the final path for the copied file, the parent dir
# is initially globbed(), and if a single directory is returned,
# it will be used. If none are found, the parent of THAT
# is checked and if it exists, the missing last component directory
# will be created. E.g. for the last example above, if
# "work/sub-1234/ses-2" exists but "work/sub-1234/ses-2/logs" doesn't
# exist, the "logs" subdirectory will be created.
module BoutiquesTaskLogsCopier

  # Note: to access the revision info of the module,
  # you need to access the constant directly, the
  # object method revision_info() won't work.
  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # This method overrides the one in BoutiquesClusterTask.
  # It will attempt to copy the stdout and stderr files
  # that CBRAIN captured, and then invoke the normal
  # post processing code.
  def save_results

    # Get the cleaning paths patterns from the descriptor
    descriptor = self.descriptor_for_save_results
    destpaths  = descriptor.custom_module_info('BoutiquesTaskLogsCopier')

    # Copy STDOUT and STDERR, if possible
    install_std_log_file(science_stdout_basename, destpaths[:stdout],     "stdout")
    install_std_log_file(science_stderr_basename, destpaths[:stderr],     "stderr")

    # Copy Boutiques configuration files
    install_std_log_file(boutiques_json_basename, destpaths[:descriptor], "boutiques descriptor")
    install_std_log_file(invoke_json_basename,    destpaths[:invoke],     "boutiques parameters")

    # Copy Runtime info file
    install_std_log_file(runtime_info_basename,   destpaths[:runtime],    "runtime info")

    # Copy sbatch/qsub script
    install_std_log_file(science_script_basename, destpaths[:jobscript],  "jobscript")

    # Create then copy the cbrain params file, if needed
    if destpaths[:cbrain_params].present?
      File.open(".cbrain_params.json","w") { |fh| fh.write JSON.pretty_generate(self.params) }
      install_std_log_file(".cbrain_params.json", destpaths[:cbrain_params], "cbrain parameters")
    end

    # Performs standard processing
    super
  end

  # Try to install a file +stdlogfile+ into the destination path
  # specified by +destpath+ . destpath can be a pattern
  # with glob components and Boutiques parameter value-keys, and
  # must be at least one level deep.
  #
  # See the examples at the top of the module.
  def install_std_log_file(stdlogfile, destpath, typeinfo)

    # If we have not configured a capture path, do nothing.
    return if destpath.blank?

    # If for some reason the task's work directory doesn't have
    # the required file, ignore it too.
    return if ! File.file?(stdlogfile)

    descriptor = self.descriptor_for_save_results

    # Prepare the substitution hash and apply it
    substitutions_by_token  = descriptor.build_substitutions_by_tokens_hash(
                                JSON.parse(File.read(self.invoke_json_basename))
                              )
    destpath   = descriptor.apply_substitutions(destpath, substitutions_by_token)
    destpath   = Pathname.new(destpath).cleanpath

    # Extract the prefix subdirectory paths (which can be globbed) and the basename
    prefixglob = destpath.parent
    basename   = destpath.basename

    # Sanity checks. These errors should never happen because the paths
    # and patterns are normally configured by the administrator, who
    # should know better than to misconfigure the module or
    # point at paths outside the task's work directory.
    cb_error "Misconfigured module BoutiquesTaskLogsCopier for #{typeinfo} with absolute path pattern '#{destpath}'" if destpath.absolute?
    if prefixglob.to_s.blank? || prefixglob.to_s == '.'
      cb_error "Misconfigured module BoutiquesTaskLogsCopier without a prefix subdirectory for #{typeinfo} '#{destpath}'"
    end

    # Try to find one and only one directory where to install the file.
    dirglobs = Pathname.glob(prefixglob)

    # If we get a pattern that matches several places, we can't do anything.
    if dirglobs.size > 1
      self.addlog "Warning: too many intermediate subdirectories match pattern '#{prefixglob}'; #{typeinfo} file not saved."
      return
    end

    # If we can't find a match at all, maybe we can find a match with just the
    # parent directory and we can create the final component.
    if dirglobs.empty?
      parent_of_prefix_glob = prefixglob.parent
      parent_of_prefix_dirs = Pathname.glob(parent_of_prefix_glob)
      if parent_of_prefix_dirs.size != 1
        self.addlog "Warning: cannot find intermediate subdirectories matching pattern '#{prefixglob}'; #{typeinfo} file not saved."
        return
      end
      mkdir_path = (Pathname.new(parent_of_prefix_dirs.first) + prefixglob.basename).to_s
      Dir.mkdir(mkdir_path)
      dirglobs = [ mkdir_path ]
    end

    destdir = dirglobs.first
    if ! path_is_in_workdir?(destdir)
      self.addlog "Misconfigured module BoutiquesTaskLogsCopier: path pattern '#{destpath}' is outside of the task's workdirectory; #{typeinfo} file not saved."
      return
    end

    self.addlog "Copying #{typeinfo} file to '#{destdir}/#{basename}'"
    FileUtils.copy_file(stdlogfile, "#{destdir}/#{basename}")

  end

end




